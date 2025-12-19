---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Bayesian Methods
---

# Bayesian Methods

_Source page: 348_



A survey of this topic is provided


In contrast with the maximum likelihood methods discussed so far, Bayesian


by M. Ghavamzadeh, S. Mannor, J.


methods balance exploration and exploitation without having to rely on heuris-


Pineau, and A. Tamar, “Bayesian


tic exploration policies. This section describes a generalization of the Bayesian


Reinforcement Learning: A Sur-


vey,”


Foundations and Trends in


methods covered in section 15.5. In


Bayesian reinforcement learning


, we specify a


Machine Learning


, vol. 8, no. 5–6,


prior distribution over all model parameters


These model parameters may


pp. 359–483, 2015. It covers meth-


ods for incorporating priors over


include the parameters governing the distribution over immediate rewards, but


reward functions, which are not


this section focuses on the parameters governing the state transition probabilities.


discussed here.


The structure of the problem can be represented using the dynamic decision


network shown in figure 16.1, wherein the model parameters are made explicit.


The shaded nodes indicate that the states are observed but the model parameters


are not. We generally assume that the model parameters are time invariant with


. However, our belief about


evolves with time as we transition to new


states.


The belief over transition probabilities can be represented using a collection


of Dirichlet distributions, one for each source state and action. Each Dirichlet


distribution represents the distribution over


for a given


and


. If


is an