---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Sequential Problems
---

# Sequential Problems

_Source page: 36_



Many important problems require that we make a series of decisions. The same


principle of maximum expected utility still applies, but optimal decision making


in a sequential context requires reasoning about future sequences of actions and


observations. This part of the book will discuss sequential decision problems in


stochastic environments, where the outcomes of our actions are uncertain. We


will focus on a general formulation of sequential decision problems under the


assumption that the model is known and that the environment is fully observable.


We will relax both of these assumptions later in the book. Our discussion will


begin with the introduction of the


Markov decision process


MDP


), the standard


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


1.6. overview


15


mathematical model for sequential decision problems. We will discuss several


approaches for finding exact solutions to these types of problems. Because large


problems sometimes do not permit exact solutions to be found efficiently, we will


discuss a collection of both offline and online approximate solution methods, along


with a type of method that involves directly searching the space of parameterized


decision policies. Finally, we will discuss approaches for validating that our


decision strategies will perform as expected when deployed in the real world.