---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: )) =
---

# )) =

_Source page: 120_



log


return


sum


bayesian_score_component


],


])


for


in 1


log


, and that


log


) =


end


A by-product of optimizing the structure with respect to the Bayesian score


is that we are able to find the right balance in the model complexity, given the


available data. We do not want a model that misses out on capturing important


relationships between variables, but we also do not want a model that has too


many parameters to be adequately learned from limited data.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


5.2. directed graph search


99


To illustrate how the Bayesian score helps us balance model complexity, con-


) =


0.5


sider the network in figure 5.1. The value of


weakly influences the value of


and


is independent of the other variables. We sample from this ‘‘true’’ model to


generate data


, and then try to learn the model structure. There are 25 possible


) =