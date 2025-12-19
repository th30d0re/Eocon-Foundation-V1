---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 286_



Exercise 12.1.


TRPO starts its line search from a new parameterization given by a natural


policy gradient update. However, TRPO conducts the line search using a different objec-


tive than the natural policy gradient. Show that the gradient of the surrogate objective


equation (12.18) used in TRPO is actually the same as the reward-to-go policy gradient


equation (11.26).


Solution:


The gradient of TRPO’s surrogate objective is


