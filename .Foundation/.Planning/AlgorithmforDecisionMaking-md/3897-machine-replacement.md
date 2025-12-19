---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Machine Replacement
---

# Machine Replacement

_Source page: 639_



minal rewards


that are equal to the


number of working parts. We do


The


machine replacement problem


is a discrete POMDP in which we maintain a


not model terminal rewards sep-


machine that creates products.


This problem is used for its relative simplicity


arately in this book. Terminal re-


wards could be included in our


and the varied size and shape of the optimal policy regions. The optimal policy


framework by explicitly including


for certain horizons even has disjoint regions in which the same action is optimal,


the horizon in the problem state.


as shown in figure F.11.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


618


appendix f. problems


Figure F.11. The


14


-step optimal


manufacture


policy for the machine replacement


problem has disjoint regions where


examine


manufacturing is optimal. Each


interrupt


0.2


polygon corresponds to the region


0.8


replace


in which a particular alpha vector


failed components


dominates.


0.4


0.6


failed component


0.6


0.4


0.8


0.2


0.2


0.6


0.8


0.4


failed components


The machine produces products for us when it is working properly. Over


time, the two primary components in the machine may break down, together or


individually, leading to defective products. We can indirectly observe whether


the machine is faulty by examining the products, or by directly examining the


components in the machine.


The problem has states