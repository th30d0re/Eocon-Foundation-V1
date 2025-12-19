---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Fast Lower Bounds
---

# Fast Lower Bounds

_Source page: 452_



The previous two sections introduced methods that can be used to produce upper


bounds on the value function represented as alpha vectors. This section introduces


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


21.4. point-based value iteration


431


a couple of methods for quickly producing lower bounds represented as alpha


vectors without any planning in the belief space. Although the upper-bound


methods can often be used directly to produce sensible policies, the lower bounds


discussed in this section are generally only used to seed other planning algorithms.


50


Figure 21.3 plots the two lower-bound methods discussed in this section.


A common lower bound is the


best-action worst-state (BAWS) lower bound


(algo-


100


rithm 21.4). It is the discounted reward obtained by taking the best action in the