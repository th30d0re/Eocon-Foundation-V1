---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 299_



pendent parameterizations as dis-


cussed in this section. The gradi-


In actor-critic methods, an actor attempts to optimize a parameterized policy


ent used to update the network


parameters is a mixture of equa-


with the help of a critic that provides a parameterized estimate of the value


tions (13.30) and (13.33). This en-


function.


hancement significantly reduces


evaluation time and feature learn-


Generally, actor-critic methods use gradient-based optimization to learn the


ing time.


parameters of both the policy and value function approximation.


The basic actor-critic method uses a policy gradient for the actor and minimizes


the squared temporal difference residual for the critic.


The generalized advantage estimate attempts to reduce the variance of its policy


gradient at the expense of some bias by accumulating temporal difference


residuals across multiple time steps.


The deterministic policy gradient can be applied to problems with continuous


action spaces and uses a deterministic policy actor and an action value critic.


Online methods, such as Monte Carlo tree search, can be used to direct the


optimization of the policy and value function estimate.