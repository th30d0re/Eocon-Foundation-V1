---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 331_



The exploration-exploitation trade-off is a balance between exploring the state-


action space for higher rewards and exploiting the already-known favorable


state actions.


Multiarmed bandit problems involve a single state where the agent receives


stochastic rewards for taking different actions.


A beta distribution can be used to maintain a belief over multiarmed bandit


rewards.


Undirected exploration strategies, including


-greedy and explore-then-commit,


are simple to implement but do not use information from previous outcomes


to guide the exploration of nongreedy actions.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


310


chapter 15. exploration and exploitation


Example 15.4. Computing the op-


Next, we have constructed the state-action tree for a two-armed bandit prob-


timal policy for a two-armed, two-


lem with a two-step horizon. State vectors are shown as


; blue


step horizon bandit problem.


arrows indicate wins and red arrows indicate losses.