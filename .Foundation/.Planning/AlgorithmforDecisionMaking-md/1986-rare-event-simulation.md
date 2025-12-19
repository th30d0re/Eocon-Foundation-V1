---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Rare Event Simulation
---

# Rare Event Simulation

_Source page: 307_



As we see in example 14.3, we may need many samples to accurately estimate


metrics where rare events are very influential, such as estimating collision proba-


bility. In the collision avoidance example, our


10


samples contained only three


collisions, as indicated by the three spikes in the plot. When we are designing al-


gorithms for high-stakes systems, such as systems that trade money or drive cars,


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


286


chapter 14. policy validation


Example 14.3. Probability of a col-


We want to estimate the probability of collision and the probability of gen-


lision and an advisory when fol-


erating an advisory. Here, we will consider the optimal and simple policies


lowing the optimal and simple col-


lision avoidance policies.


introduced in example 14.1. To evaluate these metrics, we use


10


amples


from the initial state distribution used in figure 14.1 and then perform rollouts.


The plots here show the convergence curves:


Advisory


Collision


10