use std::collections::HashSet;

use super::types::{ArtifactRef, Edge, Node};

pub fn derive_edges(nodes: &[Node]) -> Vec<Edge> {
    let mut edges = Vec::new();
    for producer in nodes {
        for consumer in nodes {
            if producer.id == consumer.id {
                continue;
            }
            let mut refs = Vec::<ArtifactRef>::new();
            let mut seen = HashSet::new();
            for produced in &producer.produces {
                if consumer
                    .consumes
                    .iter()
                    .any(|consumed| produced.matches(consumed))
                    && seen.insert(produced.clone())
                {
                    refs.push(produced.clone());
                }
            }
            if !refs.is_empty() {
                edges.push(Edge {
                    from: producer.id.clone(),
                    to: consumer.id.clone(),
                    refs,
                });
            }
        }
    }
    edges.sort_by(|a, b| (&a.from, &a.to).cmp(&(&b.from, &b.to)));
    edges
}
