---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 299_



Exercise 13.1.


Would the actor-critic method with Monte Carlo tree search, as presented


in section 13.4, be a good method for solving the cart-pole problem (appendix F.3)?


Solution:


The Monte Carlo tree search expands a tree based on visited states. The cart-pole


problem has a continuous state space, leading to a search tree with an infinite branching


factor. Use of this algorithm would require adjusting the problem, such as discretizing the


state space.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


278


chapter 13. actor-critic methods


Exercise 13.2.


In the following expressions of advantage functions, determine which ones


are correct and explain what they are referring to:


) +


) +


1:


) +


) +


1:


) +


) +


γλ


Solution:


The following table lists the correct expressions:


(b)


Advantage with temporal difference residual


(c)


Advantage estimate after


-step rollouts


(e)


Advantage with the sequence of rollout rewards


(h)


Advantage estimate with temporal difference residuals


(i)


Generalized advantage estimate


Exercise 13.3.


What are the benefits of using a temporal difference residual over a sequence


of rollout rewards and vice versa?


Solution:


Approximation using a temporal difference residual is more computationally


efficient than using a sequence of rollouts. Temporal difference residual approximation has


low variance but high bias due to using the critic value function


as an approximator of


the true value function


. On the other hand, rollout approximation has high variance


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


13.6. exercises


279


but is unbiased. Obtaining an accurate estimate using a temporal difference residual ap-


proximation typically requires far fewer samples than when using a rollout approximation,


at the cost of introducing bias into our estimate.


Exercise 13.4.


Consider the action value function given in example 13.2,


) =


. Calculate the gradients required for the deterministic policy


gradient approach.


Solution:


We need to calculate two gradients. For the actor, we need to compute


while for the critic, we need to compute


) =


1,


) =


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com