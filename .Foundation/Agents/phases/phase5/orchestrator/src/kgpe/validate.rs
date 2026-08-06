use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet, VecDeque};

use serde::{Deserialize, Serialize};

use super::derive::derive_edges;
use super::types::{ArtifactRef, Edge, Node};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum GraphError {
    Schema {
        message: String,
    },
    MissingProducer {
        node: String,
        artifact_ref: ArtifactRef,
    },
    Cycle {
        path: Vec<String>,
    },
    UnreachableNode {
        node: String,
    },
    StageLayering {
        node: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum GraphWarning {
    FanIn {
        artifact_ref: ArtifactRef,
        producers: Vec<String>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GraphReport {
    pub stages: Vec<Vec<String>>,
    pub critical_path: Vec<String>,
    pub errors: Vec<GraphError>,
    pub warnings: Vec<GraphWarning>,
}

impl GraphReport {
    pub fn is_valid(&self) -> bool {
        self.errors.is_empty()
    }
}

pub fn validate_graph(nodes: &[Node]) -> GraphReport {
    let mut errors = schema_errors(nodes);
    let edges = derive_edges(nodes);
    errors.extend(missing_producers(nodes));

    let cycle = cycle_path(nodes, &edges);
    if let Some(path) = cycle {
        errors.push(GraphError::Cycle { path });
    }

    errors.extend(unreachable_nodes(nodes, &edges));
    let (stages, critical_path, stage_errors) =
        if errors.iter().any(|e| matches!(e, GraphError::Cycle { .. })) {
            (Vec::new(), Vec::new(), Vec::new())
        } else {
            layer_and_critical_path(nodes, &edges)
        };
    errors.extend(stage_errors);

    GraphReport {
        stages,
        critical_path,
        errors,
        warnings: fan_in_warnings(nodes),
    }
}

fn schema_errors(nodes: &[Node]) -> Vec<GraphError> {
    let mut seen = HashSet::new();
    let mut errors = Vec::new();
    for node in nodes {
        if node.schema_version != 1 {
            errors.push(GraphError::Schema {
                message: format!(
                    "node '{}' has unsupported schemaVersion {}",
                    node.id, node.schema_version
                ),
            });
        }
        if node.id.trim().is_empty() || node.label.trim().is_empty() || node.retry.max_attempts == 0
        {
            errors.push(GraphError::Schema {
                message: format!("node '{}' has invalid required fields", node.id),
            });
        }
        if !seen.insert(&node.id) {
            errors.push(GraphError::Schema {
                message: format!("duplicate node id '{}'", node.id),
            });
        }
    }
    errors
}

fn missing_producers(nodes: &[Node]) -> Vec<GraphError> {
    nodes
        .iter()
        .flat_map(|node| {
            node.consumes.iter().filter_map(move |consumed| {
                let found = nodes.iter().any(|producer| {
                    producer.id != node.id
                        && producer
                            .produces
                            .iter()
                            .any(|produced| produced.matches(consumed))
                });
                (!found).then(|| GraphError::MissingProducer {
                    node: node.id.clone(),
                    artifact_ref: consumed.clone(),
                })
            })
        })
        .collect()
}

fn adjacency(
    nodes: &[Node],
    edges: &[Edge],
) -> (HashMap<String, Vec<String>>, HashMap<String, usize>) {
    let mut next = nodes
        .iter()
        .map(|n| (n.id.clone(), Vec::new()))
        .collect::<HashMap<_, _>>();
    let mut indegree = nodes
        .iter()
        .map(|n| (n.id.clone(), 0))
        .collect::<HashMap<_, _>>();
    for edge in edges {
        next.entry(edge.from.clone())
            .or_default()
            .push(edge.to.clone());
        *indegree.entry(edge.to.clone()).or_default() += 1;
    }
    for values in next.values_mut() {
        values.sort();
    }
    (next, indegree)
}

fn cycle_path(nodes: &[Node], edges: &[Edge]) -> Option<Vec<String>> {
    let (next, mut indegree) = adjacency(nodes, edges);
    let mut queue = BTreeSet::new();
    for (id, degree) in &indegree {
        if *degree == 0 {
            queue.insert(id.clone());
        }
    }
    let mut visited = 0;
    while let Some(id) = queue.pop_first() {
        visited += 1;
        if let Some(children) = next.get(&id) {
            for child in children {
                let degree = indegree
                    .get_mut(child)
                    .expect("derived edge targets known node");
                *degree -= 1;
                if *degree == 0 {
                    queue.insert(child.clone());
                }
            }
        }
    }
    if visited == nodes.len() {
        return None;
    }

    let remaining = indegree
        .into_iter()
        .filter_map(|(id, degree)| (degree > 0).then_some(id))
        .collect::<HashSet<_>>();
    fn dfs(
        id: &str,
        next: &HashMap<String, Vec<String>>,
        remaining: &HashSet<String>,
        stack: &mut Vec<String>,
        positions: &mut HashMap<String, usize>,
        done: &mut HashSet<String>,
    ) -> Option<Vec<String>> {
        positions.insert(id.to_string(), stack.len());
        stack.push(id.to_string());
        for child in next
            .get(id)
            .into_iter()
            .flatten()
            .filter(|c| remaining.contains(*c))
        {
            if let Some(start) = positions.get(child) {
                let mut path = stack[*start..].to_vec();
                path.push(child.clone());
                return Some(path);
            }
            if !done.contains(child) {
                if let Some(path) = dfs(child, next, remaining, stack, positions, done) {
                    return Some(path);
                }
            }
        }
        stack.pop();
        positions.remove(id);
        done.insert(id.to_string());
        None
    }
    let mut starts = remaining.iter().cloned().collect::<Vec<_>>();
    starts.sort();
    let mut done = HashSet::new();
    for start in starts {
        if !done.contains(&start) {
            if let Some(path) = dfs(
                &start,
                &next,
                &remaining,
                &mut Vec::new(),
                &mut HashMap::new(),
                &mut done,
            ) {
                return Some(path);
            }
        }
    }
    None
}

fn unreachable_nodes(nodes: &[Node], edges: &[Edge]) -> Vec<GraphError> {
    let (next, indegree) = adjacency(nodes, edges);
    let mut queue = indegree
        .iter()
        .filter_map(|(id, degree)| (*degree == 0).then_some(id.clone()))
        .collect::<VecDeque<_>>();
    let mut reached = HashSet::new();
    while let Some(id) = queue.pop_front() {
        if reached.insert(id.clone()) {
            queue.extend(next.get(&id).into_iter().flatten().cloned());
        }
    }
    nodes
        .iter()
        .filter(|node| !reached.contains(&node.id))
        .map(|node| GraphError::UnreachableNode {
            node: node.id.clone(),
        })
        .collect()
}

fn layer_and_critical_path(
    nodes: &[Node],
    edges: &[Edge],
) -> (Vec<Vec<String>>, Vec<String>, Vec<GraphError>) {
    let (next, mut indegree) = adjacency(nodes, edges);
    let mut queue = BTreeSet::new();
    let mut level = HashMap::<String, usize>::new();
    let mut parent = HashMap::<String, String>::new();
    for (id, degree) in &indegree {
        if *degree == 0 {
            queue.insert(id.clone());
            level.insert(id.clone(), 1);
        }
    }
    while let Some(id) = queue.pop_first() {
        let current = level[&id];
        for child in next.get(&id).into_iter().flatten() {
            if current + 1 > *level.get(child).unwrap_or(&0) {
                level.insert(child.clone(), current + 1);
                parent.insert(child.clone(), id.clone());
            }
            let degree = indegree
                .get_mut(child)
                .expect("derived edge targets known node");
            *degree -= 1;
            if *degree == 0 {
                queue.insert(child.clone());
            }
        }
    }
    let errors = nodes
        .iter()
        .filter(|n| !level.contains_key(&n.id))
        .map(|n| GraphError::StageLayering { node: n.id.clone() })
        .collect::<Vec<_>>();
    let mut grouped = BTreeMap::<usize, Vec<String>>::new();
    for (id, stage) in &level {
        grouped.entry(*stage).or_default().push(id.clone());
    }
    let stages = grouped
        .into_values()
        .map(|mut ids| {
            ids.sort();
            ids
        })
        .collect();
    let end = level
        .iter()
        .max_by(|(a_id, a_level), (b_id, b_level)| {
            a_level.cmp(b_level).then_with(|| b_id.cmp(a_id))
        })
        .map(|(id, _)| id.clone());
    let mut critical_path = Vec::new();
    if let Some(mut id) = end {
        loop {
            critical_path.push(id.clone());
            if let Some(previous) = parent.get(&id) {
                id = previous.clone();
            } else {
                break;
            }
        }
        critical_path.reverse();
    }
    (stages, critical_path, errors)
}

fn fan_in_warnings(nodes: &[Node]) -> Vec<GraphWarning> {
    let mut producers = HashMap::<ArtifactRef, Vec<String>>::new();
    for node in nodes {
        for artifact in &node.produces {
            if artifact.name.is_some() {
                producers
                    .entry(artifact.clone())
                    .or_default()
                    .push(node.id.clone());
            }
        }
    }
    let mut warnings = producers
        .into_iter()
        .filter_map(|(artifact_ref, mut ids)| {
            ids.sort();
            ids.dedup();
            (ids.len() > 1).then_some(GraphWarning::FanIn {
                artifact_ref,
                producers: ids,
            })
        })
        .collect::<Vec<_>>();
    warnings.sort_by(|a, b| format!("{:?}", a).cmp(&format!("{:?}", b)));
    warnings
}
