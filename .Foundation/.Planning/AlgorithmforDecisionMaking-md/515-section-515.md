---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) + (
---

# ) + (

_Source page: 62_



) =


independent parameters.


Exercise 2.6.


Suppose that we have four continuous random variables,


, and


, and we want to construct a linear Gaussian model of


; that is,


1:2


given


1:2


. How many independent parameters are required for this model?


Solution:


In this case, our mean vector for the Gaussian distribution is two-dimensional


and requires four independent parameters for the transformation matrix


and two inde-


pendent parameters for the bias vector


. We also require three independent parameters


for the covariance matrix


. In total, we need


independent parameters to


specify this model:


) =


My


Exercise 2.7.


Given the following Bayesian network, in which each node can take on one of


four values, how many independent parameters are there? What is the percent reduction


in the number of independent parameters required when using the following Bayesian


network compared to using a full joint probability table?


Solution:


The number of independent parameters for each node is equal to


, where


is the number of values that the node can take on and


is the number of parents that the


node has. Variable


has


has


12


has


48


has


has


12


, and


has


48


independent


parameters. There are


126


total independent parameters for this Bayesian network.


The number of independent parameters required to specify a joint probability table


over


variables that can take on


values is equal to


. Therefore, specifying a joint


probability table would require