---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Directed Exploration Strategies
---

# Directed Exploration Strategies

_Source page: 325_



Directed exploration


uses information gathered from previous pulls to guide explo-


ration of the nongreedy actions. For example, the


softmax strategy


(algorithm 15.5)


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


304


chapter 15. exploration and exploitation


Example 15.2. Application of the


We would like to apply the


-greedy exploration strategy to a two-armed


-greedy exploration strategy to a


bandit. We can construct the model with a uniform prior and the exploration


two-armed bandit problem.


policy with


0.3


model


BanditModel


([


Beta


(),


Beta