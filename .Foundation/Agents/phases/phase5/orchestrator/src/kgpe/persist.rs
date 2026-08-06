use std::collections::HashMap;
use std::fmt;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use super::engine::{GraphEngine, MutationError};
use super::types::{Node, NodeState};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GraphStateFile {
    schema_version: u32,
    nodes: Vec<Node>,
    states: HashMap<String, NodeState>,
    attempts: HashMap<String, u32>,
    resume_position: Vec<String>,
}

#[derive(Debug)]
pub enum PersistError {
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
    UnsupportedSchema(u32),
    InvalidGraph(MutationError),
    Write {
        path: PathBuf,
        source: std::io::Error,
    },
    Serialize(serde_json::Error),
    StateMismatch(String),
}

impl fmt::Display for PersistError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}
impl std::error::Error for PersistError {}

pub fn save_graph_state(path: &Path, engine: &GraphEngine) -> Result<(), PersistError> {
    let file = GraphStateFile {
        schema_version: 1,
        nodes: engine.nodes.clone(),
        states: engine.states.clone(),
        attempts: engine.attempts.clone(),
        resume_position: engine.ready_set(),
    };
    let text = serde_json::to_string_pretty(&file).map_err(PersistError::Serialize)?;
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|source| PersistError::Write {
            path: parent.to_path_buf(),
            source,
        })?;
    }
    std::fs::write(path, text).map_err(|source| PersistError::Write {
        path: path.to_path_buf(),
        source,
    })
}

pub fn load_graph_state(path: &Path) -> Result<GraphEngine, PersistError> {
    if !path.is_file() {
        return Err(PersistError::Missing {
            path: path.to_path_buf(),
        });
    }
    let text = std::fs::read_to_string(path).map_err(|source| PersistError::Read {
        path: path.to_path_buf(),
        source,
    })?;
    let file: GraphStateFile =
        serde_json::from_str(&text).map_err(|source| PersistError::Parse {
            path: path.to_path_buf(),
            source,
        })?;
    if file.schema_version != 1 {
        return Err(PersistError::UnsupportedSchema(file.schema_version));
    }
    let mut engine = GraphEngine::new(file.nodes).map_err(PersistError::InvalidGraph)?;
    if file.states.keys().any(|id| !engine.states.contains_key(id))
        || engine.states.keys().any(|id| !file.states.contains_key(id))
    {
        return Err(PersistError::StateMismatch(
            "persisted states do not match graph nodes".into(),
        ));
    }
    engine.states = file.states;
    engine.attempts = file.attempts;
    if engine.ready_set() != file.resume_position {
        return Err(PersistError::StateMismatch(
            "resumePosition does not match computed ready set".into(),
        ));
    }
    Ok(engine)
}
