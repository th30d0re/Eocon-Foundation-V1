---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Asynchronous Value Iteration
---

# Asynchronous Value Iteration

_Source page: 167_



Value iteration tends to be computationally intensive, as every entry in the value


function


. In


asynchronous value


is updated in each iteration to obtain


iteration


, only a subset of the states are updated with each iteration. Asynchronous


value iteration is still guaranteed to converge on the optimal value function,


provided that each state is updated an infinite number of times.


One common asynchronous value iteration method,


Gauss-Seidel value iteration


(algorithm 7.9), sweeps through an ordering of the states and applies the Bellman


update in place:


max