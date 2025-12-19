---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Discrete State Filter
---

# Discrete State Filter

_Source page: 402_



In a POMDP, the agent does not directly observe the underlying state of the


Figure 19.1. A dynamic decision


environment. Instead, the agent receives an observation, which belongs to some


network for the POMDP problem


formulation. As with figure 7.1, in-


observation space


, at each time step. The probability of observing


, given that


formational edges into the action


the agent took action


and transitioned to state


, is given by


. If


nodes are not shown.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


19.2. discrete state filter


381


is continuous, then


is a probability density. Figure 19.1 shows the


dynamic decision network associated with POMDPs. Algorithm 19.1 provides an


implementation of the POMDP data structure.


Algorithm 19.1.


A data struc-


struct