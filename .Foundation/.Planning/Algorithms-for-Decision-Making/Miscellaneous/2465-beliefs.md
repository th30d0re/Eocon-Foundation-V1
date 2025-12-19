---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Beliefs
---

# Beliefs

_Source page: 401_



A POMDP is an MDP with state uncertainty. The agent receives a potentially


imperfect


observation


of the current state rather than the true state. From the past


sequence of observations and actions, the agent develops an understanding of


the world. This chapter discusses how the


belief


of the agent can be represented


by a probability distribution over the underlying state. Various algorithms are


presented for updating our belief based on the observation and action taken by


Different methods for belief up-


the agent.


We can perform exact belief updates if the state space is discrete or if


dating are discussed in the context


certain linear Gaussian assumptions are met. In cases where these assumptions


of robotic applications by S. Thrun,


do not hold, we can use approximations based on linearization or sampling.


W. Burgard, and D. Fox,


Probabilis-


tic Robotics


. MIT Press, 2006.