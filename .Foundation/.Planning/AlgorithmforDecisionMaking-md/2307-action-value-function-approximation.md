---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Action Value Function Approximation
---

# Action Value Function Approximation

_Source page: 365_



in


International Conference on Ma-


chine Learning (ICML)


, 1999.


The algorithms discussed so far in this chapter have assumed discrete state and


action spaces where the action value function can be stored in a lookup table. We


can adapt our algorithms to use value function approximation, allowing us to


apply them to problems with large or continuous spaces and generalize from


limited experience. Similar to the approach taken in chapter 8 in the context of a


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


344


chapter 17. model-free methods


known model, we will use


to represent a parametric approximation of


11


11


In recent years, a major focus has


our action value function when the model is unknown.


been on


deep reinforcement learning


To illustrate this concept, we will derive a version of


-learning that uses


where deep neural networks are


our parametric approximation. We want to minimize the loss between our ap-


used for this parametric approxi-


mation. A discussion of practical


proximation and the optimal action value function


, which we define to


implementations is provided by L.


12


be


Graesser and W. L. Keng,


Founda-


tions of Deep Reinforcement Learning