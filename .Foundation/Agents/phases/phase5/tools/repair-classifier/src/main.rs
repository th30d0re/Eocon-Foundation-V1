/// foundation-repair-classifier
///
/// Reads compiler error text from stdin, classifies the error pattern, and selects
/// the best repair strategy from a JSON registry using UCB1 exploration.
///
/// I/O contract (matches lib/build/repair.sh Bash implementation):
///   stdin  : raw compiler error text
///   --registry <path> : path to repair_strategies.json (optional)
///   stdout : "<error_pattern>\t<chosen_strategy>"  (single line, no trailing newline)
///   exit 0 : always on valid input
///   exit 1 : bad arguments
///
/// Error patterns (from classify_error_pattern in repair.sh):
///   type_error | missing_import | protocol_conformance | access_control |
///   nil_unwrap | syntax | generic | other | unknown
///
/// Strategy selection (from select_repair_strategy):
///   - No registry or no entry for pattern → "minimal_fix"
///   - Unexplored strategy (pulls == 0) → return immediately (first found)
///   - All explored → UCB1: max(mean + 1.414 * sqrt(ln(total) / pulls))

use std::io::{self, Read};
use regex::Regex;
use serde_json::Value;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let registry_path = parse_registry_arg(&args);

    let mut error_text = String::new();
    if io::stdin().read_to_string(&mut error_text).is_err() {
        error_text = String::new();
    }

    let pattern = classify_error_pattern(&error_text);
    let strategy = select_repair_strategy(&pattern, registry_path.as_deref());

    print!("{}\t{}", pattern, strategy);
}

fn parse_registry_arg(args: &[String]) -> Option<String> {
    let mut iter = args.iter().skip(1);
    while let Some(arg) = iter.next() {
        if arg == "--registry" {
            return iter.next().cloned();
        }
    }
    None
}

/// Port of classify_error_pattern from lib/build/repair.sh
fn classify_error_pattern(errors: &str) -> &'static str {
    if errors.trim().is_empty() {
        return "unknown";
    }

    let e = errors.to_lowercase();

    if contains_any(&e, &["cannot convert", "type.*mismatch", "expected.*found.*type"]) {
        "type_error"
    } else if contains_any(&e, &["no such module", "unresolved identifier", "use of unresolved"]) {
        "missing_import"
    } else if contains_any(&e, &["does not conform to protocol", "protocol.*requirement"]) {
        "protocol_conformance"
    } else if contains_any(&e, &["inaccessible.*protection", "internal.*access", "private.*access"]) {
        "access_control"
    } else if contains_any(&e, &["unexpectedly found nil", "force unwrap", "optional.*unwrapped"]) {
        "nil_unwrap"
    } else if contains_any(&e, &["expected expression", "missing brace", "syntax error"]) {
        "syntax"
    } else if contains_any(&e, &["generic.*specialization", "type.*parameter.*inferred"]) {
        "generic"
    } else {
        "other"
    }
}

/// Check if any of the patterns (plain substring or simple .*  regex) match the text.
fn contains_any(text: &str, patterns: &[&str]) -> bool {
    for p in patterns {
        if p.contains(".*") {
            if let Ok(re) = Regex::new(p) {
                if re.is_match(text) {
                    return true;
                }
            }
        } else if text.contains(p) {
            return true;
        }
    }
    false
}

/// Port of select_repair_strategy from lib/build/repair.sh (UCB1 variant).
fn select_repair_strategy(pattern: &str, registry_path: Option<&str>) -> String {
    let path = match registry_path {
        Some(p) => p,
        None => return "minimal_fix".to_string(),
    };

    let content = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(_) => return "minimal_fix".to_string(),
    };

    let root: Value = match serde_json::from_str(&content) {
        Ok(v) => v,
        Err(_) => return "minimal_fix".to_string(),
    };

    let strategies = &root["patterns"][pattern]["strategies"];
    if strategies.is_null() || !strategies.is_object() {
        return "minimal_fix".to_string();
    }

    let map = match strategies.as_object() {
        Some(m) if !m.is_empty() => m,
        _ => return "minimal_fix".to_string(),
    };

    // Collect (strategy, successes, failures)
    let mut entries: Vec<(&str, f64, f64)> = Vec::new();
    for (name, stats) in map {
        let s = stats["successes"].as_f64().unwrap_or(0.0);
        let f = stats["failures"].as_f64().unwrap_or(0.0);
        entries.push((name.as_str(), s, f));
    }

    // Unexplored strategy: prioritize (matches Bash: return immediately on first pulls==0)
    for (name, s, f) in &entries {
        if s + f == 0.0 {
            return name.to_string();
        }
    }

    // All explored: UCB1
    let total_pulls: f64 = entries.iter().map(|(_, s, f)| s + f).sum();
    let total_pulls = if total_pulls == 0.0 { 1.0 } else { total_pulls };

    let mut best_strategy = "minimal_fix";
    let mut best_score = f64::NEG_INFINITY;

    for (name, s, f) in &entries {
        let pulls = s + f;
        if pulls == 0.0 {
            continue;
        }
        let mean = s / pulls;
        let ucb = mean + 1.414 * (total_pulls.ln() / pulls).sqrt();
        if ucb > best_score {
            best_score = ucb;
            best_strategy = name;
        }
    }

    best_strategy.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classify_type_error() {
        assert_eq!(
            classify_error_pattern("cannot convert value of type String to expected argument type Int"),
            "type_error"
        );
    }

    #[test]
    fn classify_missing_import() {
        assert_eq!(
            classify_error_pattern("use of unresolved identifier SwiftUI"),
            "missing_import"
        );
    }

    #[test]
    fn classify_protocol_conformance() {
        assert_eq!(
            classify_error_pattern("does not conform to protocol Equatable"),
            "protocol_conformance"
        );
    }

    #[test]
    fn classify_nil_unwrap() {
        assert_eq!(
            classify_error_pattern("unexpectedly found nil while unwrapping an Optional value"),
            "nil_unwrap"
        );
    }

    #[test]
    fn classify_syntax() {
        assert_eq!(
            classify_error_pattern("expected expression after return statement"),
            "syntax"
        );
    }

    #[test]
    fn classify_empty() {
        assert_eq!(classify_error_pattern(""), "unknown");
    }

    #[test]
    fn classify_other() {
        assert_eq!(classify_error_pattern("some completely unknown error XYZ123"), "other");
    }

    #[test]
    fn strategy_no_registry() {
        assert_eq!(select_repair_strategy("type_error", None), "minimal_fix");
    }

    #[test]
    fn strategy_unexplored_first() {
        // Write a temp registry with one unexplored strategy
        let dir = std::env::temp_dir();
        let path = dir.join("test_registry_unexplored.json");
        let json = r#"{
            "patterns": {
                "type_error": {
                    "strategies": {
                        "minimal_fix": { "successes": 5, "failures": 1 },
                        "rewrite_signature": { "successes": 0, "failures": 0 }
                    }
                }
            }
        }"#;
        std::fs::write(&path, json).unwrap();
        let result = select_repair_strategy("type_error", path.to_str());
        std::fs::remove_file(&path).ok();
        assert_eq!(result, "rewrite_signature");
    }

    #[test]
    fn strategy_ucb1_selects_best() {
        let dir = std::env::temp_dir();
        let path = dir.join("test_registry_ucb1.json");
        // All explored, minimal_fix has good ratio
        let json = r#"{
            "patterns": {
                "type_error": {
                    "strategies": {
                        "minimal_fix":       { "successes": 8, "failures": 2 },
                        "rewrite_signature": { "successes": 1, "failures": 9 }
                    }
                }
            }
        }"#;
        std::fs::write(&path, json).unwrap();
        let result = select_repair_strategy("type_error", path.to_str());
        std::fs::remove_file(&path).ok();
        // minimal_fix: mean=0.8, pulls=10; rewrite: mean=0.1, pulls=10; total=20
        // UCB1 minimal_fix = 0.8 + 1.414*sqrt(ln(20)/10) ≈ 0.8 + 1.414*0.547 ≈ 1.574
        // UCB1 rewrite     = 0.1 + 1.414*sqrt(ln(20)/10) ≈ 0.874  → minimal_fix wins
        assert_eq!(result, "minimal_fix");
    }

    #[test]
    fn strategy_unknown_pattern() {
        let dir = std::env::temp_dir();
        let path = dir.join("test_registry_unknown.json");
        std::fs::write(&path, r#"{"patterns":{}}"#).unwrap();
        let result = select_repair_strategy("no_such_pattern", path.to_str());
        std::fs::remove_file(&path).ok();
        assert_eq!(result, "minimal_fix");
    }
}
