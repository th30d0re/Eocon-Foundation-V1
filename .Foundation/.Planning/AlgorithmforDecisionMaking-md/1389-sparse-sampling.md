---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Sparse Sampling
---

# Sparse Sampling

_Source page: 209_



M. J. Kearns, Y. Mansour, and


A method known as


sparse sampling


(algorithm 9.4) attempts to reduce the


A. Y. Ng, “A Sparse Sampling Al-


branching factor of forward search and branch and bound. Instead of branching


gorithm for Near-Optimal Plan-


on all possible next states, we consider only a limited number of samples of the


ning in Large Markov Decision Pro-


cesses,”


Machine Learning


, vol. 49,


next state. Although the sampling of the next state results in an approximation,


no. 2–3, pp. 193–208, 2002.


this method can work well in practice and can significantly reduce computation.


If we draw


samples of the next state for each action node in the search tree,


the computational complexity is