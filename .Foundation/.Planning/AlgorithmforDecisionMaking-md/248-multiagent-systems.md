---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Multiagent Systems
---

# Multiagent Systems

_Source page: 38_



Up to this point, there has only been one agent making decisions within the envi-


ronment. This part expands the previous four parts to multiple agents, discussing


the challenges that arise from interaction uncertainty. We begin by discussing


simple games, where a group of agents simultaneously each select an action.


The result is an individual reward for each agent based on the combined joint


action. The


Markov game


MG


) represents a generalization of both simple games


to multiple states and the MDP to multiple agents. Consequently, the agents


select actions that can stochastically change the state of a shared environment.


Algorithms for MGs rely on reinforcement learning due to uncertainty about


the policies of the other agents. A


partially observable Markov game