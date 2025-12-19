---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: 
---

# 

_Source page: 98_



nan


nan


0.5


0.5


As we can see, the first and second parental instantiations of the second


variable


leads to


nan


(‘‘not a number’’) estimates. Because there are no


observations of those two parental instantiations in the data, the denominator


of equation (4.16) equals zero, making the parameter estimate undefined.


Most of the other parameters are not


nan


. For example, the parameter


112


0.5


means that the maximum likelihood estimate of


is


0.5


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


4.2. bayesian parameter learning


77


be


. Believing that there is zero chance of a midair collision is not a reason-


able conclusion unless our prior hypothesis was, for example, that all flights were


perfectly safe.


The Bayesian approach to parameter learning involves estimating


the posterior distribution over


given our data


. Instead of obtaining a point


estimate


as in maximum likelihood estimation, we obtain a distribution. This


distribution can help us quantify our uncertainty about the true value of


. We


can convert this distribution into a point estimate by computing the expectation: