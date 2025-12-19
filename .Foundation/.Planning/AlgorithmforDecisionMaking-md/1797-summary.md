---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 285_



be adjusted for both algorithms,


which would affect where the max-


imum is in each case.


The gradient ascent algorithm can use the gradient estimates obtained from the


methods discussed in the previous chapter to iteratively improve our policy.


Gradient ascent can be made more robust by scaling, clipping, or forcing the


size of the improvement steps to be uniform.


The natural gradient approach uses a first-order approximation of the objective


function with a constraint on the divergence between the trajectory distribution


at each step, approximated using an estimate of the Fisher information matrix.


Trust region policy optimization involves augmenting the natural gradient


method with a line search to further improve the policy without additional


trajectory simulations.


We can use a pessimistic lower bound of the TRPO objective to obtain a clamped


surrogate objective that performs similarly without the need for line search.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


264


chapter 12. policy gradient optimization