use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ArtifactType {
    #[serde(rename = "constitution.root")]
    ConstitutionRoot,
    #[serde(rename = "constitution.sub")]
    ConstitutionSub,
    #[serde(rename = "plan.doc")]
    PlanDoc,
    #[serde(rename = "plan.test")]
    PlanTest,
    #[serde(rename = "wave.subplan")]
    WaveSubplan,
    #[serde(rename = "wave.subtest")]
    WaveSubtest,
    #[serde(rename = "wave.unittest")]
    WaveUnittest,
    #[serde(rename = "questions.doc")]
    QuestionsDoc,
    #[serde(rename = "decision.log")]
    DecisionLog,
    #[serde(rename = "stages.graph")]
    StagesGraph,
    #[serde(rename = "code.module")]
    CodeModule,
    #[serde(rename = "test.result")]
    TestResult,
    #[serde(rename = "guide.doc")]
    GuideDoc,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ArtifactRef {
    #[serde(rename = "type")]
    pub artifact_type: ArtifactType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}

impl ArtifactRef {
    pub fn unnamed(artifact_type: ArtifactType) -> Self {
        Self {
            artifact_type,
            name: None,
        }
    }

    pub fn named(artifact_type: ArtifactType, name: impl Into<String>) -> Self {
        Self {
            artifact_type,
            name: Some(name.into()),
        }
    }

    pub fn matches(&self, other: &Self) -> bool {
        self.artifact_type == other.artifact_type
            && match (&self.name, &other.name) {
                (Some(left), Some(right)) => left == right,
                (None, None) => true,
                _ => false,
            }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum NodeKind {
    Agent,
    Work,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Gate {
    None,
    Human,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "type",
    rename_all = "lowercase",
    rename_all_fields = "camelCase"
)]
pub enum ExecSpec {
    Script {
        path: String,
        #[serde(default)]
        args: Vec<String>,
    },
    Wave {
        plan_path: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RetrySpec {
    pub max_attempts: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Node {
    pub schema_version: u32,
    pub id: String,
    pub kind: NodeKind,
    pub label: String,
    pub exec: ExecSpec,
    #[serde(default)]
    pub consumes: Vec<ArtifactRef>,
    #[serde(default)]
    pub produces: Vec<ArtifactRef>,
    pub gate: Gate,
    pub retry: RetrySpec,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Edge {
    pub from: String,
    pub to: String,
    pub refs: Vec<ArtifactRef>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum NodeState {
    #[default]
    Pending,
    Ready,
    Running,
    AwaitingApproval,
    Succeeded,
    Failed,
    HumanIntervention,
    Skipped,
}

impl NodeState {
    pub fn satisfies_dependency(self) -> bool {
        matches!(self, Self::Succeeded | Self::Skipped)
    }
}
