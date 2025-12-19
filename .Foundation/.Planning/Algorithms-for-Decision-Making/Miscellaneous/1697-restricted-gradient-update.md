---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Restricted Gradient Update
---

# Restricted Gradient Update

_Source page: 273_



The remaining algorithms in this chapter attempt to optimize an approximation


of the objective function


, subject to a constraint that the policy parameters at


the next step


are not too far from


at the current step. The constraint takes the


form


, where


is a free parameter in the algorithm. The methods


differ in their approximation of


and the form of


. This section describes a


simple


restricted step


method.


We use the first-order Taylor approximation (appendix A.12) obtained from


our gradient estimate at


to approximate