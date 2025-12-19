---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Correlated Equilibrium
---

# Correlated Equilibrium

_Source page: 520_



The


correlated equilibrium


generalizes the Nash equilibrium concept by relaxing the


assumption that the agents act independently. The joint action in this case comes


from a full joint distribution. A


correlated joint policy


is a single distribution


over the joint actions of all agents. Consequently, the actions of the various agents


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


24.5. correlated equilibrium


499


Example 24.3. Deterministic and


Suppose that we wish to find a Nash equilibrium for the prisoner’s dilemma


stochastic Nash equilibria.


from example 24.1. If both agents always defect, both receive


reward.


Any deviation by any agent will result in a


reward for that agent; hence,


there is no incentive to deviate. Having both agents defect is thus a Nash


equilibrium for the prisoner’s dilemma.


Suppose that we now wish to find a Nash equilibrium for the rock-paper-


scissors scenario from example 24.2. Any deterministic strategy by one agent


can be easily countered by the other agent. For example, if agent


plays


rock, then agent


’s best response is paper. Because there is no deterministic


Nash equilibrium for rock-paper-scissors, we know that there must be one


involving stochastic policies. Suppose that each agent selects from the actions


uniformly at random. This solution produces an expected utility of


for both


agents: