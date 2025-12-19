---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 469_



ter


11


iterations. The value func-


tion plot shows the discrete belief


The QMDP algorithm assumes perfect observability after the first step, resulting


points as white dots. This policy ap-


proximates the exact policy given


in an upper bound on the true value function.


in appendix F.8.


The fast informed bound provides a tighter upper bound on the value function


than QMDP by accounting for the observation model.


Point-based value iteration provides a lower bound on the value function using


alpha vectors at a finite set of beliefs.


Randomized point-based value iteration performs updates at randomly se-


lected points in the belief set until the values at all points in the set are improved.


The sawtooth upper bound allows iterative improvement of the fast informed


bound using an efficient point-set representation.


Carefully selecting which belief points to use in point-based value iteration


can improve the quality of the resulting policies.


Sawtooth heuristic search attempts to tighten the upper and lower bounds of the


value function represented by sawtooth pairs and alpha vectors, respectively.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


448


chapter 21. offline belief state planning


One approach to approximately solving POMDPs is to discretize the belief


space, and then to apply dynamic programming to extract an upper bound on


the value function and a policy.