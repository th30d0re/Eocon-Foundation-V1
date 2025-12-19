---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Undirected Exploration Strategies
---

# Undirected Exploration Strategies

_Source page: 323_



There are several


ad hoc exploration


strategies that are commonly used to balance


exploration with exploitation. This section discusses a type of ad hoc exploration


called


undirected exploration


, where we do not use information from previous


outcomes to guide exploration of nongreedy actions.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


302


chapter 15. exploration and exploitation


Example 15.1. Posterior probability


Suppose we have a two-armed bandit that we have played six times. The


distributions and expected payouts


first arm has


win and


losses, and the other arm has


wins and


loss.


for a multiarmed bandit.


Assuming a uniform prior, the posterior distribution for


Beta