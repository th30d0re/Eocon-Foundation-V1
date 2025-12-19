---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 354_



Table 16.1. Transition data.


Exercise 16.1.


Suppose we have an agent interacting in an environment with three states


and two actions with unknown transition and reward models. We perform one sequence


of direct interaction with the environment. Table 16.1 tabulates the state, action, reward,


and resulting state. Use maximum likelihood estimation to estimate the transition and


reward functions from this data.


Solution:


We first tabulate the number of transitions from each state and action


, the


rewards received


, and the maximum likelihood estimate of the reward function


) =


as follows:


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


16.8. exercises


333


) =


In the next set of tables, we compute the number of observed transitions


and


the maximum likelihood estimate of the transition model


) =


When


) =


, we use a uniform distribution over the resulting states.


) =


1/3


1/3


1/3


1/2


1/2


1/3


2/3


1/2


1/2


Exercise 16.2.


Provide a lower bound and an upper bound on the number of updates that


could be performed during an iteration of prioritized sweeping.


Solution:


A lower bound on the number of updates performed in an iteration of prioritized


sweeping is


. This could occur during our first iteration using a maximum likelihood


model, where the only nonzero entry in our transition model is


. Since no


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


334


chapter 16. model-based methods


state-action pairs


transition to


, our priority queue would be empty, and thus the


only update performed would be for


An upper bound on the number of updates performed in an iteration of prioritized


sweeping is


|S|


. Suppose that we just transitioned to


, and


for all


and


If we do not provide a maximum number of updates, we will perform


|S|


updates. If we


provide a maximum number of updates


|S|


, the upper bound is reduced to


Exercise 16.3.


In performing Bayesian reinforcement learning of the transition model


parameters for a discrete MDP with state space


and action space


, how many indepen-


dent parameters are there when using Dirichlet distributions to represent uncertainty over


the transition model?


Solution:


For each state and action, we specify a Dirichlet distribution over the transition


probability parameters, so we will have