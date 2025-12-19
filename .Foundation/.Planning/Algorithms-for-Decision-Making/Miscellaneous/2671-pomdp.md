---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 438_



of value iteration in terms of con-


value iteration


(algorithm 20.8) begins by constructing all one-step plans. We


ditional plans and alpha vectors.


prune any plans that are never optimal for any initial belief. Then, we expand all


For a version that only uses alpha


vectors, see A. R. Cassandra, M. L.


combinations of one-step plans to produce two-step plans. Again, we prune any


Littman, and N. L. Zhang, “Incre-


suboptimal plans from consideration. This procedure of alternating between ex-


mental Pruning: A Simple, Fast, Ex-


act Method for Partially Observ-


pansion and pruning is repeated until the desired horizon is reached. Figure 20.3


able Markov Decision Processes,”


demonstrates value iteration on the crying baby problem.


in


Conference on Uncertainty in Arti-


ficial Intelligence (UAI)


, 1997.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


20.5. value iteration


417


Example 20.3. The expected util-


We can construct all two-step plans for the crying baby problem. There are


ity over the belief space for all


27


such plans.


two-step plans for the crying baby


problem (appendix F.7). The thick


The expected utility for each plan in belief space is plotted below. We find


lines are optimal for some beliefs,


that two plans dominate all others. These dominating plans are the only ones


whereas the thin lines are domi-


that need to be considered as subplans for optimal three-step plans.


nated.


10


15


20


25


0.2


0.6


0.8


0.4


hungry


Algorithm 20.8. Value iteration for


function


value_iteration


::