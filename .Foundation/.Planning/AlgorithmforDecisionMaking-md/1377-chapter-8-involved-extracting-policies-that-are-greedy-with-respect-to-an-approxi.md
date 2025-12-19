---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Chapter 8 involved extracting policies that are greedy with respect to an approxi-
---

# Chapter 8 involved extracting policies that are greedy with respect to an approxi-

_Source page: 205_



The lookahead strategy was orig-


mate value function


through the use of one-step lookahead.


A simple online


inally introduced in algorithm 7.2


strategy involves acting greedily with respect to values estimated through simu-


as part of our discussion of exact


lation to depth


. To run a simulation, we need a policy to simulate. Of course,


solution methods.


we do not know the optimal policy, but we can use what is called a


rollout policy


instead. Rollout policies are typically stochastic, with actions drawn from a distri-


bution


. To produce these rollout simulations, we use a


generative model


to generate successor states


from the distribution


. This


generative model can be implemented through draws from a random number


generator, which can be easier to implement in practice compared to explicitly


representing the distribution


Algorithm 9.1 combines one-step lookahead with values estimated through


rollout. This approach often results in better behavior than that of the original


rollout policy, but optimality is not guaranteed. It can be viewed as an approximate


form of policy improvement used in the policy iteration algorithm (section 7.4).


A simple variation of this algorithm is to use multiple rollouts to arrive at a better


estimate of the expected discounted return. If we run


simulations for each


action and resulting state, the time complexity is