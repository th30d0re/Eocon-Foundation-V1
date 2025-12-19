---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exact Belief State Planning
---

# Exact Belief State Planning

_Source page: 429_



The objective in a POMDP is to choose actions that maximize the accumulation


of reward while interacting with the environment. In contrast with MDPs, states


are not directly observable, requiring the agent to use its past history of actions


and observations to inform a belief. As discussed in the previous chapter, beliefs


can be represented as probability distributions over states. There are different


approaches for computing an optimal policy that maps beliefs to actions given


A discussion of exact solution


models of the transitions, observations, and rewards.


One approach is to convert


methods is provided by L. P. Kael-


a POMDP into an MDP and apply dynamic programming. Other approaches


bling, M. L. Littman, and A. R.


include representing policies as conditional plans or as piecewise linear value


Cassandra, “Planning and Acting


in Partially Observable Stochas-


functions over the belief space. The chapter concludes with an algorithm for


tic Domains,”


Artificial Intelligence


computing an optimal policy that is analogous to value iteration for MDPs.


vol. 101, no. 1–2, pp. 99–134, 1998.