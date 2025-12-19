---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 508_



Controllers are policy representations that do not rely on exploring or main-


taining beliefs.


Controllers consist of nodes, an action selection function, and a successor


selection function.


Nodes and the controller graph are abstract; however, they can be interpreted


as sets of the countably infinite reachable beliefs.


The value function for a controller node can be interpreted as an alpha vector.


Policy iteration alternates between policy evaluation, which computes the


utilities for each node, and policy improvement, which adds new nodes.


Pruning during policy iteration can help reduce the exponential growth in


nodes with each improvement step.


Nonlinear programming reformulates finding the optimal fixed-sized con-


troller as a general optimization problem, allowing off-the-shelf solvers and


techniques to be used.


Controller gradient ascent climbs in the space of policies to improve the value


function directly, benefiting from an explicit, POMDP-based gradient step.