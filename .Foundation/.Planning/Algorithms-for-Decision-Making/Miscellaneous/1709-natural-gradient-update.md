---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Natural Gradient Update
---

# Natural Gradient Update

_Source page: 275_



S.


The


natural gradient


method


is a variation of the restricted step method discussed


Amari,


“Natural


Gradient


Works Efficiently in Learning,”


in the previous section to better handle situations when some components of the


Neural Computation


, vol. 10, no. 2,


parameter space are more sensitive than others.


Sensitivity


in this context refers


pp. 251–276, 1998.


to how much the utility of a policy varies with respect to small changes in one of


the parameters. The sensitivity in gradient methods is largely determined by the


choice of scaling of the policy parameters. The natural policy gradient method


makes the search direction


invariant to parameter scaling. Figure 12.2 illustrates


the differences between the true gradient and the natural gradient.


Figure 12.2.


A comparison of


natural gradient


true gradient


the true gradient and the natu-


ral gradient on the simple regu-


lator problem (see appendix F.5).


0.4


The true gradient generally points


strongly in the negative


direc-


tion, whereas the natural gradient


generally points toward the opti-


0.2


mum (black dot) at