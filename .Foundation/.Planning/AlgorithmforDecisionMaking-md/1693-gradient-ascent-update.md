---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Gradient Ascent Update
---

# Gradient Ascent Update

_Source page: 271_



We can use


gradient ascent


(reviewed in appendix A.11) to find a policy parame-


terized by


that maximizes the expected utility


. Gradient ascent is a type


of


iterated ascent


method, which involves taking steps in the parameter space at


each iteration in an attempt to improve the quality of the associated policy. All


the methods discussed in this chapter are iterated ascent methods, but they differ


in how they take steps. The gradient ascent method discussed in this section


takes steps in the direction of


, which may be estimated using one of the


methods discussed in the previous chapter. The update of


is