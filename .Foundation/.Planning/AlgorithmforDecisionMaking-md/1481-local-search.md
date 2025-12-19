---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Local Search
---

# Local Search

_Source page: 237_



A common approach to optimization is


local search


, where we begin with an


initial parameterization and incrementally move from neighbor to neighbor in


the search space until convergence occurs. We discussed this type of approach in


chapter 5, in the context of optimizing Bayesian network structures with respect


to the Bayesian score. Here, we are optimizing policies parameterized by


. We


are trying to find a value of


that maximizes


There are many local search algorithms, but this section will focus on the


R. Hooke and T. A. Jeeves, “Direct


Hooke-Jeeves method


(algorithm 10.2).


This algorithm assumes that our policy


Search Solution of Numerical and


is parameterized by an


-dimensional vector


. The algorithm takes a step of


Statistical Problems,”


Journal of the


size


in each of the coordinate directions from the current


. These


points