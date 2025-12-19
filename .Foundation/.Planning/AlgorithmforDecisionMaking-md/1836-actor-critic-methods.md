---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Actor-Critic Methods
---

# Actor-Critic Methods

_Source page: 289_



The previous chapter discussed ways to improve a parameterized policy through


gradient information estimated from rollouts. This chapter introduces


actor-critic


methods


, which use an estimate of a value function to help direct the optimization.


The actor, in this context, is the policy, and the critic is the value function. Both


are trained in parallel. We will discuss several methods that differ in whether


they approximate the value function, advantage function, or action value func-


tion. Most focus on stochastic policies, but we will also discuss one method that


supports deterministic policies that output continuous actions. Finally, we will


discuss a way to incorporate an online method for generating more informative


trajectories for training the actor and critic.