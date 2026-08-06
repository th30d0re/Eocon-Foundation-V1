use std::collections::HashSet;
use std::fmt;
use std::path::{Path, PathBuf};

use super::types::Node;

#[derive(Debug)]
pub enum ManifestError {
    Missing {
        path: PathBuf,
    },
    Read {
        path: PathBuf,
        source: std::io::Error,
    },
    Parse {
        path: PathBuf,
        source: serde_json::Error,
    },
    UnsupportedSchema {
        path: PathBuf,
        version: u32,
    },
    Invalid {
        path: PathBuf,
        message: String,
    },
    DuplicateId {
        id: String,
        first: PathBuf,
        second: PathBuf,
    },
}

impl fmt::Display for ManifestError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Missing { path } => {
                write!(f, "manifest not found at expected path {}", path.display())
            }
            Self::Read { path, source } => {
                write!(f, "failed to read manifest {}: {}", path.display(), source)
            }
            Self::Parse { path, source } => {
                write!(f, "failed to parse manifest {}: {}", path.display(), source)
            }
            Self::UnsupportedSchema { path, version } => write!(
                f,
                "manifest {} has unsupported schemaVersion {}",
                path.display(),
                version
            ),
            Self::Invalid { path, message } => {
                write!(f, "invalid manifest {}: {}", path.display(), message)
            }
            Self::DuplicateId { id, first, second } => write!(
                f,
                "duplicate node id '{}' in {} and {}",
                id,
                first.display(),
                second.display()
            ),
        }
    }
}

impl std::error::Error for ManifestError {}

pub fn load_manifest(path: &Path) -> Result<Node, ManifestError> {
    if !path.is_file() {
        return Err(ManifestError::Missing {
            path: path.to_path_buf(),
        });
    }
    let text = std::fs::read_to_string(path).map_err(|source| ManifestError::Read {
        path: path.to_path_buf(),
        source,
    })?;
    let node: Node = serde_json::from_str(&text).map_err(|source| ManifestError::Parse {
        path: path.to_path_buf(),
        source,
    })?;
    validate_node(&node, path)?;
    Ok(node)
}

pub fn load_manifests(paths: &[PathBuf]) -> Result<Vec<Node>, ManifestError> {
    let mut nodes = Vec::new();
    let mut ids = std::collections::HashMap::<String, PathBuf>::new();
    for path in paths {
        for node in load_manifest_file(path)? {
            if let Some(first) = ids.insert(node.id.clone(), path.clone()) {
                return Err(ManifestError::DuplicateId {
                    id: node.id,
                    first,
                    second: path.clone(),
                });
            }
            nodes.push(node);
        }
    }
    Ok(nodes)
}

fn load_manifest_file(path: &Path) -> Result<Vec<Node>, ManifestError> {
    if !path.is_file() {
        return Err(ManifestError::Missing {
            path: path.to_path_buf(),
        });
    }
    let text = std::fs::read_to_string(path).map_err(|source| ManifestError::Read {
        path: path.to_path_buf(),
        source,
    })?;
    let value: serde_json::Value =
        serde_json::from_str(&text).map_err(|source| ManifestError::Parse {
            path: path.to_path_buf(),
            source,
        })?;
    let nodes: Vec<Node> = if value.is_array() {
        serde_json::from_value(value).map_err(|source| ManifestError::Parse {
            path: path.to_path_buf(),
            source,
        })?
    } else {
        vec![serde_json::from_value(value).map_err(|source| ManifestError::Parse {
            path: path.to_path_buf(),
            source,
        })?]
    };
    if nodes.is_empty() {
        return Err(ManifestError::Invalid {
            path: path.to_path_buf(),
            message: "manifest array must contain at least one node".into(),
        });
    }
    for node in &nodes {
        validate_node(node, path)?;
    }
    Ok(nodes)
}

fn validate_node(node: &Node, path: &Path) -> Result<(), ManifestError> {
    if node.schema_version != 1 {
        return Err(ManifestError::UnsupportedSchema {
            path: path.to_path_buf(),
            version: node.schema_version,
        });
    }
    if node.id.trim().is_empty() || node.label.trim().is_empty() {
        return Err(ManifestError::Invalid {
            path: path.to_path_buf(),
            message: "id and label must not be empty".into(),
        });
    }
    if node.retry.max_attempts == 0 {
        return Err(ManifestError::Invalid {
            path: path.to_path_buf(),
            message: "retry.maxAttempts must be at least 1".into(),
        });
    }
    let mut produced = HashSet::new();
    if node
        .produces
        .iter()
        .any(|artifact| !produced.insert(artifact))
    {
        return Err(ManifestError::Invalid {
            path: path.to_path_buf(),
            message: "produces contains a duplicate artifact ref".into(),
        });
    }
    Ok(())
}
