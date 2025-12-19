#!/usr/bin/env python3
"""
Decision-Making Calculator for Foundation Planning

Utilities for:
- Expected Value calculations
- Upper Confidence Bound (UCB) for exploration
- Bayesian belief updates
- Multi-attribute utility
- Value of Information

Based on "Algorithms for Decision Making" by Kochenderfer et al.
"""

import math
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass


@dataclass
class Action:
    """Represents a possible action/decision."""

    name: str
    outcomes: List[Tuple[float, float]]  # [(probability, value), ...]
    cost: float = 0.0

    def expected_value(self) -> float:
        """Calculate expected value of this action."""
        ev = sum(prob * value for prob, value in self.outcomes)
        return ev - self.cost


@dataclass
class Arm:
    """Multi-armed bandit arm (e.g., LLM model choice)."""

    name: str
    successes: int
    failures: int

    @property
    def trials(self) -> int:
        return self.successes + self.failures

    @property
    def success_rate(self) -> float:
        if self.trials == 0:
            return 0.5  # Prior
        return self.successes / self.trials

    def ucb_score(self, total_trials: int, exploration_constant: float = 2.0) -> float:
        """
        Calculate Upper Confidence Bound score.

        UCB = mean_reward + c * sqrt(ln(total_trials) / trials_this_arm)

        Args:
            total_trials: Total number of trials across all arms
            exploration_constant: Higher = more exploration (default 2.0)

        Returns:
            UCB score (higher = should try this arm next)
        """
        if self.trials == 0:
            return float("inf")  # Always try untried arms first

        mean_reward = self.success_rate
        exploration_bonus = exploration_constant * math.sqrt(
            math.log(total_trials) / self.trials
        )
        return mean_reward + exploration_bonus


class DecisionCalculator:
    """Main calculator for decision-making metrics."""

    @staticmethod
    def expected_value(actions: List[Action]) -> Dict[str, float]:
        """
        Calculate expected value for each action.

        Args:
            actions: List of Action objects

        Returns:
            Dictionary mapping action names to EV
        """
        return {action.name: action.expected_value() for action in actions}

    @staticmethod
    def best_action(actions: List[Action]) -> Tuple[str, float]:
        """
        Find action with highest expected value.

        Returns:
            (action_name, expected_value)
        """
        ev_dict = DecisionCalculator.expected_value(actions)
        best = max(ev_dict.items(), key=lambda x: x[1])
        return best

    @staticmethod
    def ucb_selection(arms: List[Arm], exploration_constant: float = 2.0) -> str:
        """
        Select next arm using Upper Confidence Bound algorithm.

        Args:
            arms: List of Arm objects
            exploration_constant: Exploration parameter (default 2.0)

        Returns:
            Name of arm to try next
        """
        total_trials = sum(arm.trials for arm in arms)

        if total_trials == 0:
            # No trials yet, pick randomly (or first)
            return arms[0].name

        scores = {
            arm.name: arm.ucb_score(total_trials, exploration_constant) for arm in arms
        }

        return max(scores.items(), key=lambda x: x[1])[0]

    @staticmethod
    def bayesian_update(
        prior: float, likelihood_if_true: float, likelihood_if_false: float
    ) -> float:
        """
        Update belief using Bayes' rule.

        P(H|E) = P(E|H) * P(H) / P(E)

        Args:
            prior: P(hypothesis) before evidence
            likelihood_if_true: P(evidence | hypothesis is true)
            likelihood_if_false: P(evidence | hypothesis is false)

        Returns:
            Updated probability (posterior)
        """
        # P(E) = P(E|H) * P(H) + P(E|¬H) * P(¬H)
        evidence_prob = likelihood_if_true * prior + likelihood_if_false * (1 - prior)

        # P(H|E) = P(E|H) * P(H) / P(E)
        posterior = (likelihood_if_true * prior) / evidence_prob

        return posterior

    @staticmethod
    def multi_attribute_utility(
        attributes: Dict[str, float], weights: Dict[str, float]
    ) -> float:
        """
        Calculate multi-attribute utility.

        U = Σ wᵢ * uᵢ

        Args:
            attributes: {attribute_name: utility_value}
            weights: {attribute_name: weight} (should sum to 1.0)

        Returns:
            Overall utility score
        """
        return sum(weights[attr] * value for attr, value in attributes.items())

    @staticmethod
    def value_of_information(
        ev_with_info: float, ev_without_info: float, info_cost: float
    ) -> float:
        """
        Calculate value of gathering more information.

        VOI = EV(with info) - EV(without info) - Cost(info)

        If VOI > 0, it's worth gathering the information.

        Args:
            ev_with_info: Expected value if we get the information
            ev_without_info: Expected value without the information
            info_cost: Cost to gather the information

        Returns:
            Value of information (positive = worth gathering)
        """
        return ev_with_info - ev_without_info - info_cost

    @staticmethod
    def regret(best_possible: float, actual_obtained: float) -> float:
        """
        Calculate regret (how much worse we did than optimal).

        Args:
            best_possible: Best outcome we could have achieved (in hindsight)
            actual_obtained: Actual outcome we got

        Returns:
            Regret value (lower is better, 0 is optimal)
        """
        return best_possible - actual_obtained


def print_decision_analysis(actions: List[Action]):
    """Pretty print analysis of actions."""
    print("\n" + "=" * 60)
    print("DECISION ANALYSIS")
    print("=" * 60)

    for action in actions:
        ev = action.expected_value()
        print(f"\nAction: {action.name}")
        print(f"  Cost: {action.cost}")
        print(f"  Outcomes:")
        for prob, value in action.outcomes:
            print(f"    {prob * 100:5.1f}% chance → {value:+7.2f} value")
        print(f"  Expected Value: {ev:+7.2f}")

    best_name, best_ev = DecisionCalculator.best_action(actions)
    print(f"\n{'=' * 60}")
    print(f"RECOMMENDATION: {best_name} (EV = {best_ev:+.2f})")
    print("=" * 60 + "\n")


def print_ucb_analysis(arms: List[Arm], exploration_constant: float = 2.0):
    """Pretty print UCB analysis of arms."""
    total_trials = sum(arm.trials for arm in arms)

    print("\n" + "=" * 60)
    print("UCB EXPLORATION ANALYSIS")
    print("=" * 60)
    print(f"Total trials: {total_trials}")
    print(f"Exploration constant: {exploration_constant}")

    print(
        "\n{:<15} {:>8} {:>8} {:>10} {:>10}".format(
            "Arm", "Success", "Total", "Rate", "UCB Score"
        )
    )
    print("-" * 60)

    for arm in arms:
        ucb = arm.ucb_score(total_trials, exploration_constant)
        ucb_str = "∞" if ucb == float("inf") else f"{ucb:.3f}"
        print(
            "{:<15} {:>8} {:>8} {:>9.1%} {:>10}".format(
                arm.name, arm.successes, arm.trials, arm.success_rate, ucb_str
            )
        )

    next_arm = DecisionCalculator.ucb_selection(arms, exploration_constant)
    print(f"\n{'=' * 60}")
    print(f"NEXT SELECTION: {next_arm}")
    print("=" * 60 + "\n")


# Example usage and tests
if __name__ == "__main__":
    print("\n" + "=" * 70)
    print("FOUNDATION DECISION-MAKING CALCULATOR")
    print("=" * 70)

    # Example 1: Expected Value for test comprehensiveness decision
    print("\n\nEXAMPLE 1: Test Template Comprehensiveness")
    print("-" * 70)

    minimal = Action(
        name="Minimal Tests",
        outcomes=[
            (0.50, 90),  # 50% success → value 90
            (0.50, 60),  # 50% failure → value 60
        ],
        cost=10,  # 2 days * 5 cost per day
    )

    standard = Action(
        name="Standard Tests",
        outcomes=[
            (0.75, 75),  # 75% success → value 75
            (0.25, 60),  # 25% minor issues → value 60
        ],
        cost=25,  # 5 days * 5 cost per day
    )

    comprehensive = Action(
        name="Comprehensive Tests",
        outcomes=[
            (0.85, 60),  # 85% success → value 60
            (0.15, 50),  # 15% minor issues → value 50
        ],
        cost=40,  # 8 days * 5 cost per day
    )

    print_decision_analysis([minimal, standard, comprehensive])

    # Example 2: UCB for LLM model selection
    print("\n\nEXAMPLE 2: LLM Model Selection (UCB)")
    print("-" * 70)

    gpt4 = Arm(name="GPT-4", successes=42, failures=8)
    claude = Arm(name="Claude-3", successes=25, failures=5)
    gemini = Arm(name="Gemini", successes=3, failures=2)

    print_ucb_analysis([gpt4, claude, gemini], exploration_constant=2.0)

    # Example 3: Bayesian belief update
    print("\n\nEXAMPLE 3: Bayesian Belief Update")
    print("-" * 70)

    prior = 0.6  # 60% confident Phase 1 will take 3 weeks
    likelihood_if_true = (
        0.2  # If 3 weeks is right, 20% chance we're at 25% after 1 week
    )
    likelihood_if_false = 0.5  # If 3 weeks is wrong, 50% chance we're at 25%

    posterior = DecisionCalculator.bayesian_update(
        prior, likelihood_if_true, likelihood_if_false
    )

    print(f"Prior belief (3 weeks): {prior:.1%}")
    print(f"Evidence: 25% complete after 1 week (expected 33%)")
    print(f"Posterior belief (3 weeks): {posterior:.1%}")
    print(f"Belief decreased by: {(prior - posterior) * 100:.1f} percentage points")

    # Example 4: Value of Information
    print("\n\nEXAMPLE 4: Value of Information")
    print("-" * 70)

    ev_without = 65  # Expected value proceeding with current understanding
    ev_with = 80  # Expected value if we gather more info first
    info_cost = 10  # Cost to gather info (e.g., 2 days research)

    voi = DecisionCalculator.value_of_information(ev_with, ev_without, info_cost)

    print(f"EV without additional info: {ev_without}")
    print(f"EV with additional info: {ev_with}")
    print(f"Cost to gather info: {info_cost}")
    print(f"Value of Information: {voi:+.2f}")

    if voi > 0:
        print(f"✓ WORTH gathering more information (VOI = {voi:+.2f})")
    else:
        print(f"✗ NOT worth gathering info (proceed with current knowledge)")

    # Example 5: Multi-attribute utility
    print("\n\nEXAMPLE 5: Multi-Attribute Utility")
    print("-" * 70)

    option_a = {"speed": 0.8, "quality": 0.6, "cost": 0.7, "scalability": 0.9}

    option_b = {"speed": 0.6, "quality": 0.9, "cost": 0.5, "scalability": 0.7}

    weights = {"speed": 0.3, "quality": 0.4, "cost": 0.2, "scalability": 0.1}

    utility_a = DecisionCalculator.multi_attribute_utility(option_a, weights)
    utility_b = DecisionCalculator.multi_attribute_utility(option_b, weights)

    print("Option A:")
    for attr, value in option_a.items():
        print(f"  {attr:15s}: {value:.2f} (weight: {weights[attr]:.2f})")
    print(f"  {'Overall Utility':15s}: {utility_a:.3f}")

    print("\nOption B:")
    for attr, value in option_b.items():
        print(f"  {attr:15s}: {value:.2f} (weight: {weights[attr]:.2f})")
    print(f"  {'Overall Utility':15s}: {utility_b:.3f}")

    print(f"\n{'=' * 70}")
    if utility_a > utility_b:
        print(f"RECOMMENDATION: Option A (utility = {utility_a:.3f})")
    else:
        print(f"RECOMMENDATION: Option B (utility = {utility_b:.3f})")
    print("=" * 70)

    print("\n\n" + "=" * 70)
    print("See DECISION-LOG.md for how to apply these calculations to real decisions")
    print("=" * 70 + "\n")
