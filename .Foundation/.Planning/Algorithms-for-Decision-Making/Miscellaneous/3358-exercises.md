---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 552_



Exercise 25.1.


Show that MGs are extensions of both MDPs and simple games. Show this


by formulating an MDP as an MG and by formulating a simple game as an MG.


Solution:


MGs generalize simple games. For any simple game with


, and


, we can


construct an MG by just having a single state that self-loops. In other words, this MG has


) =


, and


) =


MGs generalize MDPs. For any MDP with


, and


, we can construct an MG


by just assigning the agents to be this single agent. In other words, this MG has


) =


, and


) =


Exercise 25.2.


For an agent


, given the fixed policies of other agents


, can there be a


stochastic best response that yields a greater utility than a deterministic best response?


Why do we consider stochastic policies in a Nash equilibrium?


Solution:


No, if given fixed policies of other agents


, a deterministic best response is


sufficient to obtain the highest utility. The best response can be formulated as solving an


MDP, as described in section 25.2. It has been shown that deterministic policies are sufficient


to provide optimal utility maximization. Hence, the same is true for a best response in an


MG.


In a Nash equilibrium, a best response has to hold for all agents. Although a determin-


istic best response might be equal in utility to a stochastic one, an equilibrium may require


stochastic responses in order to prevent other agents from wanting to deviate.


Exercise 25.3.


This chapter discussed only stationary Markov policies. What other cate-


gories of policies are there?


Solution:


A so-called


behavioral policy


is one that has a dependence on the complete


history


. Such policies depend on the history of play of other agents. A


= (


1:


1:


nonstationary Markov policy


is one that depends on the time step


, but not on the


complete history. For example, in the predator-prey hex world domain, for the first 10 time


steps, the action at a hex might be to go east, and after 10 time steps, to go west.


There can be Nash equilibria that are in the space of nonstationary, non-Markov joint


policies; stationary, non-Markov joint policies; and so forth. However, it has been proven


that every stationary MG has a stationary Markov Nash equilibrium.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


25.8. exercises


531


Exercise 25.4.


In MGs, fictitious play requires the utilities to be estimated. List different


approaches to compute utilities, with their benefits and drawbacks.


Solution:


Algorithm 25.7 performs a single backup for the visited state


and all joint actions


. This approach has the benefit of being relatively efficient because it is a single backup.


Updating all joint actions at that state results in exploring actions that were not observed.


The drawback of this approach is that we may need to do this update at all states many


times to obtain a suitable policy.


An alternative is only to update the visited state and the joint action that was actually


taken, which results in a faster update step. The drawback is that it requires many more


steps to explore the full range of joint actions.


Another alternative is to perform value iteration at all states


until convergence at every


update step. Recall that the model of the opponent changes on each update. This induces a


new MDP, as described for deterministic best response in section 25.2.1. Consequently, we


would need to rerun value iteration after each update. The benefit of this approach is that


it can result in the most informed decision at each step because the utilities


consider all


states over time. The drawback is that the update step is very computationally expensive.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com