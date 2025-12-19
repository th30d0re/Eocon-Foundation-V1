---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Generalized Advantage Estimation
---

# Generalized Advantage Estimation

_Source page: 291_



Generalized advantage estimation


(algorithm 13.2) is an actor-critic method that


uses a more general version of the advantage estimate shown in equation (13.2)


J. Schulman, P. Moritz, S. Levine,


that allows us to balance between bias and variance.


Approximation with the


M. Jordan, and P. Abbeel, “High-


temporal difference residual has low variance, but it introduces bias due to a


Dimensional Continuous Control


potentially inaccurate


. An alternative is to replace


used to approximate


Using Generalized Advantage Esti-


mation,” in


International Conference


with the sequence of rollout rewards