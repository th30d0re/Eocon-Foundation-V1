---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Adversarial Analysis
---

# Adversarial Analysis

_Source page: 313_



It can be useful to study the robustness of a policy from the perspective of an


adversarial analysis


. At each time step, an


adversary


selects the state that results


from applying the action specified by the policy from the current state. The


adversary has two objectives to balance: minimizing our return and maximizing


the likelihood of the resulting trajectory according to our transition model. We


can transform our original problem into an adversarial problem. The adversarial


state space is the same as in the original problem, but the adversarial action space


is the state space of the original problem. The adversarial reward is