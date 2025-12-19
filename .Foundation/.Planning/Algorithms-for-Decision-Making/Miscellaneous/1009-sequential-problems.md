---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: sequential problems
---

# sequential problems

_Source page: 153_



Up to this point, we have assumed that we make a single decision at one point in


time, but many important problems require that we make a series of decisions. The


same principle of maximum expected utility still applies, but optimal decision


making in a sequential context requires reasoning about future sequences of


actions and observations. This part of the book will discuss sequential decision


problems in stochastic environments. We will focus on a general formulation of


sequential decision problems under the assumption that the model is known and


that the environment is fully observable. We will relax both of these assumptions


later. Our discussion will begin with the introduction of the


Markov decision process


MDP


), the standard mathematical model for sequential decision problems. We


will discuss several approaches for finding exact solutions. Because large problems


sometimes do not permit exact solutions to be efficiently found, we will discuss a


collection of both offline and online approximate solution methods, along with


a type of method that involves directly searching the space of parameterized


decision policies. Finally, we will discuss approaches for validating that our


decision strategies will perform as expected when deployed in the real world.