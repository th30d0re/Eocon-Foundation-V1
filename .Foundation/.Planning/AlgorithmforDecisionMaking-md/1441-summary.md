---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 230_



Online methods plan from the current state, focusing computation on states


that are reachable.


Receding horizon planning involves planning to a certain horizon and then


replanning with each step.


Lookahead with rollouts involves acting greedily with respect to values es-


timated using simulations of a rollout policy; it is computationally efficient


compared to other algorithms, but there are no guarantees on performance.


Forward search considers all state-action transitions up to a certain depth,


resulting in computational complexity that grows exponentially in both the


number of states and the number of actions.


Branch and bound uses upper and lower bound functions to prune portions of


the search tree that will not lead to a better outcome in expectation.


Sparse sampling avoids the exponential complexity in the number of states by


limiting the number of sampled transitions from every search node.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


9.11. exercises


209


Monte Carlo tree search guides search to promising areas of the search space


by taking actions that balance exploration with exploitation.


Heuristic search runs simulations of a policy that is greedy with respect to a


value function that is updated along the way using lookahead.


Labeled heuristic search reduces computation by not reevaluating states whose


values have converged.


Open-loop planning aims to find the best possible sequence of actions and can


be computationally efficient if the optimization problem is convex.