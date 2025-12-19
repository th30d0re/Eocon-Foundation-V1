---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Deterministic Variables
---

# Deterministic Variables

_Source page: 54_



10


Some problems may involve a


deterministic variable


, whose value is fixed given


evidence. In other words, we assign probability


to a value that is a determin-


Figure 2.10. The logit model with


istic function of its evidence. Using a conditional probability table to represent


and different values for


a discrete deterministic variable is possible, but it is wasteful. A single variable


instantiation will have probability


for each parental instantiation, and the re-


15


For an in-depth treatment of


maining entries will be


. Our implementation can take advantage of this sparsity


Bayesian networks and other forms


for a more compact representation. Algorithms in this text using discrete factors


of probabilistic graphical models,


see D. Koller and N. Friedman,


treat any assignments missing from the factor table as having value


, making it


Probabilistic Graphical Models: Prin-


so that we have to store only the assignments that have nonzero probability.


ciples and Techniques


. MIT Press,


2009.


16


Appendix A.16 reviews common