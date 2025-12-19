---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 333_



Exercise 15.1.


Consider again the three-armed bandit problems in which each arm has a


win probability drawn uniformly between


and


. Compare the softmax, quantile, and


UCB1 exploration strategies. Qualitatively, what values for


, and


produce the highest


expected reward on randomly generated bandit problems?


Solution:


Here we plot the expected reward per step for each of the three strategies. Again,


the effectiveness of the parameterization depends on the problem horizon, so several


different depths are shown as well.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


312


chapter 15. exploration and exploitation


softmax exploration with constant precision


horizon =


10


0.7


horizon =


100


horizon =


200


0.6


mean reward


0.5


20


30


50


10


40


quantile exploration


horizon =


10


0.7


horizon =


100


horizon =


200


0.6


mean reward


0.5


0.2


0.6


0.8


0.4