---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Nash Equilibrium
---

# Nash Equilibrium

_Source page: 542_



A. M. Fink, “Equilibrium in a


Stochastic


-Person Game,”


Journal


The Nash equilibrium concept can be generalized to MGs.


As with simple games,


of Science of the Hiroshima University,


Series A-I


, vol. 28, no. 1, pp. 89–93,


all agents perform a best response to one another and have no incentive to deviate.


1964.


All finite MGs with a discounted infinite horizon have a Nash equilibrium.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


25.4. fictitious play


521


We can find a Nash equilibrium by solving a nonlinear optimization problem


similar to the one that we solved in the context of simple games. This problem


minimizes the sum of the lookahead utility deviations and constrains the policies


to be valid distributions:


minimize