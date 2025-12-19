---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Fictitious Play
---

# Fictitious Play

_Source page: 527_



Wright


and


K.


Leyton-


Brown,


“Behavioral


Game


Theoretic


Models:


Bayesian


An alternative approach for computing policies for different agents is to have them


Framework for Parameter Analy-


play each other in simulation and learn how to best respond. Algorithm 24.10


sis,” in


International Conference on


Autonomous Agents and Multiagent


provides an implementation of the simulation loop. At each iteration, we evaluate


Systems (AAMAS)


, 2012.


the various policies to obtain a joint action, and then this joint action is used by the


agents to update their policies. We can use a number of ways to update the policies


in response to observed joint actions. This section focuses on


fictitious play


, where


the agents use maximum likelihood estimates (as described in section 16.1) of the


policies followed by the other agents. Each agent follows its own best response,


14


14


G. W. Brown, “Iterative Solution


assuming that the other agents act according to those estimates.


of Games by Fictitious Play,”


Activ-


To compute a maximum likelihood estimate, agent


tracks the number of


ity Analysis of Production and Alloca-


times that agent


takes action


, storing it in table


. These counts can be


tion


, vol. 13, no. 1, pp. 374–376, 1951.


J. Robinson, “An Iterative Method


initialized to any value, but they are often initialized to


to create initial uniform


of Solving a Game,”


Annals of Math-


uncertainty. Agent


computes its best response, assuming that each agent


follows


ematics


, pp. 296–301, 1951.


the stochastic policy: