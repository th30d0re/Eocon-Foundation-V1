---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Gradient Ascent
---

# Gradient Ascent

_Source page: 503_



A fixed-size controller policy can be iteratively improved using gradient ascent


N. Meuleau, K.


(covered in appendix A.11).


Although the gradient is challenging to compute,


E. Kim, L. P. Kael-


bling, and A. R. Cassandra, “Solv-


this opens up controller optimization to a wide variety of gradient-based opti-


ing POMDPs by Searching the


mization techniques. Algorithm 23.6 implements controller gradient ascent using


Space of Finite Policies,” in


Confer-


ence on Uncertainty in Artificial Intel-


algorithm 23.7.


ligence (UAI)


, 1999.


Consider an explicit description of the nonlinear problem from section 23.3.


For initial belief


and an arbitrary initial controller node


, we seek to maximize


as follows: