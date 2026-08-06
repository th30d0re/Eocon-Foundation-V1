use std::collections::{HashMap, HashSet, VecDeque};
use std::fmt;

use serde::{Deserialize, Serialize};

use super::derive::derive_edges;
use super::types::{ArtifactRef, Edge, Gate, Node, NodeState};
use super::validate::{validate_graph, GraphReport};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GraphEngine {
    pub nodes: Vec<Node>,
    pub edges: Vec<Edge>,
    pub states: HashMap<String, NodeState>,
    pub attempts: HashMap<String, u32>,
    pub report: GraphReport,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MutationError {
    InvalidGraph(GraphReport),
    UnknownNode(String),
    DuplicateNode(String),
    InvalidState {
        node: String,
        expected: &'static str,
    },
    ArtifactHasNoProducer(ArtifactRef),
}

impl fmt::Display for MutationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidGraph(report) => write!(f, "graph validation failed: {:?}", report.errors),
            Self::UnknownNode(node) => write!(f, "unknown node '{}'", node),
            Self::DuplicateNode(node) => write!(f, "duplicate node id '{}'", node),
            Self::InvalidState { node, expected } => {
                write!(f, "node '{}' must be {}", node, expected)
            }
            Self::ArtifactHasNoProducer(reference) => {
                write!(f, "artifact {:?} has no producer", reference)
            }
        }
    }
}

impl std::error::Error for MutationError {}

impl GraphEngine {
    pub fn new(nodes: Vec<Node>) -> Result<Self, MutationError> {
        let report = validate_graph(&nodes);
        if !report.is_valid() {
            return Err(MutationError::InvalidGraph(report));
        }
        let edges = derive_edges(&nodes);
        let states = nodes
            .iter()
            .map(|node| (node.id.clone(), NodeState::Pending))
            .collect();
        let attempts = nodes.iter().map(|node| (node.id.clone(), 0)).collect();
        let mut engine = Self {
            nodes,
            edges,
            states,
            attempts,
            report,
        };
        engine.refresh_ready();
        Ok(engine)
    }

    pub fn ready_set(&self) -> Vec<String> {
        let mut ids = self
            .nodes
            .iter()
            .filter(|node| {
                self.states.get(&node.id) == Some(&NodeState::Ready)
                    || (self.states.get(&node.id) == Some(&NodeState::Pending)
                        && self.predecessors_satisfied(&node.id))
            })
            .map(|node| node.id.clone())
            .collect::<Vec<_>>();
        ids.sort();
        ids
    }

    pub fn refresh_ready(&mut self) {
        let ready = self
            .nodes
            .iter()
            .filter(|node| {
                self.states.get(&node.id) == Some(&NodeState::Pending)
                    && self.predecessors_satisfied(&node.id)
            })
            .map(|node| node.id.clone())
            .collect::<Vec<_>>();
        for id in ready {
            self.states.insert(id, NodeState::Ready);
        }
    }

    fn predecessors_satisfied(&self, id: &str) -> bool {
        self.edges.iter().filter(|edge| edge.to == id).all(|edge| {
            self.states
                .get(&edge.from)
                .copied()
                .unwrap_or(NodeState::Pending)
                .satisfies_dependency()
        })
    }

    pub fn start(&mut self, id: &str) -> Result<(), MutationError> {
        if self.states.get(id) != Some(&NodeState::Ready) {
            return Err(MutationError::InvalidState {
                node: id.into(),
                expected: "Ready",
            });
        }
        self.states.insert(id.into(), NodeState::Running);
        *self.attempts.entry(id.into()).or_default() += 1;
        Ok(())
    }

    pub fn apply_exit_code(&mut self, id: &str, code: i32) -> Result<NodeState, MutationError> {
        if self.states.get(id) != Some(&NodeState::Running) {
            return Err(MutationError::InvalidState {
                node: id.into(),
                expected: "Running",
            });
        }
        let gate = self
            .nodes
            .iter()
            .find(|node| node.id == id)
            .ok_or_else(|| MutationError::UnknownNode(id.into()))?
            .gate;
        let state = match code {
            0 if gate == Gate::Human => NodeState::AwaitingApproval,
            0 => NodeState::Succeeded,
            10 | 11 => NodeState::Failed,
            20 => NodeState::HumanIntervention,
            _ => NodeState::Failed,
        };
        self.states.insert(id.into(), state);
        self.refresh_ready();
        Ok(state)
    }

    pub fn approve(&mut self, id: &str) -> Result<(), MutationError> {
        if self.states.get(id) != Some(&NodeState::AwaitingApproval) {
            return Err(MutationError::InvalidState {
                node: id.into(),
                expected: "AwaitingApproval",
            });
        }
        self.states.insert(id.into(), NodeState::Succeeded);
        self.refresh_ready();
        Ok(())
    }

    pub fn retry(&mut self, id: &str) -> Result<NodeState, MutationError> {
        let node = self
            .nodes
            .iter()
            .find(|node| node.id == id)
            .ok_or_else(|| MutationError::UnknownNode(id.into()))?;
        if self.states.get(id) != Some(&NodeState::Failed) {
            return Err(MutationError::InvalidState {
                node: id.into(),
                expected: "Failed",
            });
        }
        let state = if self.attempts.get(id).copied().unwrap_or(0) < node.retry.max_attempts {
            NodeState::Ready
        } else {
            NodeState::HumanIntervention
        };
        self.states.insert(id.into(), state);
        self.revalidate()?;
        Ok(state)
    }

    pub fn amend(&mut self, reference: &ArtifactRef) -> Result<Vec<String>, MutationError> {
        let producers = self
            .nodes
            .iter()
            .filter(|node| {
                node.produces
                    .iter()
                    .any(|produced| produced.matches(reference))
            })
            .map(|node| node.id.clone())
            .collect::<Vec<_>>();
        if producers.is_empty() {
            return Err(MutationError::ArtifactHasNoProducer(reference.clone()));
        }
        let mut invalidated = producers.iter().cloned().collect::<HashSet<_>>();
        let mut queue = VecDeque::from(producers);
        while let Some(id) = queue.pop_front() {
            for child in self
                .edges
                .iter()
                .filter(|edge| edge.from == id)
                .map(|edge| edge.to.clone())
            {
                if invalidated.insert(child.clone()) {
                    queue.push_back(child);
                }
            }
        }
        self.revalidate()?;
        for id in &invalidated {
            self.states.insert(id.clone(), NodeState::Pending);
            self.attempts.insert(id.clone(), 0);
        }
        self.refresh_ready();
        let mut ids = invalidated.into_iter().collect::<Vec<_>>();
        ids.sort();
        Ok(ids)
    }

    pub fn append(&mut self, node: Node) -> Result<(), MutationError> {
        if self.nodes.iter().any(|existing| existing.id == node.id) {
            return Err(MutationError::DuplicateNode(node.id));
        }
        let mut candidate = self.nodes.clone();
        candidate.push(node.clone());
        let report = validate_graph(&candidate);
        if !report.is_valid() {
            return Err(MutationError::InvalidGraph(report));
        }
        self.nodes = candidate;
        self.edges = derive_edges(&self.nodes);
        self.report = report;
        self.states.insert(node.id.clone(), NodeState::Pending);
        self.attempts.insert(node.id, 0);
        self.refresh_ready();
        Ok(())
    }

    fn revalidate(&mut self) -> Result<(), MutationError> {
        let report = validate_graph(&self.nodes);
        if !report.is_valid() {
            return Err(MutationError::InvalidGraph(report));
        }
        self.edges = derive_edges(&self.nodes);
        self.report = report;
        Ok(())
    }
}
