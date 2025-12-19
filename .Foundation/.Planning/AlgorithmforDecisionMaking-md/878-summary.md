---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 128_



Fitting a Bayesian network to data requires selecting the Bayesian network


structure that dictates the conditional dependencies between variables.


Bayesian approaches to structure learning maximize the Bayesian score, which


is related to the probability of the graph structure given a data set.


The Bayesian score promotes simpler structures for smaller data sets and


supports more complicated structures for larger data sets.


The number of possible structures is superexponential in the number of vari-


ables, and finding a structure that maximizes the Bayesian score is NP-hard.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


5.6. exercises


107


Directed graph search algorithms like K2 and local search can be efficient but


do not guarantee optimality.


Methods like partially directed graph search traverse the space of Markov


equivalence classes, which may be more efficient than searching the larger


space of directed acyclic graphs.