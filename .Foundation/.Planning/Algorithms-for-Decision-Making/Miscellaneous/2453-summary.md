---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 393_



Imitation learning involves learning the desired behavior from expert demon-


stration without the use of a reward function.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


372


chapter 18. imitation learning


One type of imitation learning is behavioral cloning, which produces a stochas-


tic policy that maximizes the conditional likelihood of the actions in the data


set.


When an expert can be queried multiple times, we can use iterative approaches


like data set aggregation or stochastic mixing iterative learning.


Inverse reinforcement learning involves inferring a reward function from expert


data and then using traditional methods for finding an optimal policy.


Maximum margin inverse reinforcement learning attempts to find a policy that


matches the frequency of binary features found in the expert data set.


Maximum entropy inverse reinforcement learning frames the problem of find-


ing the best reward parameter as a maximum likelihood estimation problem,


which it tries to solve using gradient ascent.


Generative adversarial imitation learning iteratively optimizes a discriminator


and a policy; the discriminator tries to discriminate between decisions made


by the policy and decisions made by the expert, and the policy attempts to


deceive the discriminator.