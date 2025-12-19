---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Bayesian Network Scoring
---

# Bayesian Network Scoring

_Source page: 119_



We want to be able to score a network structure


based on how well it models


the data. A maximum a posteriori approach to structure learning involves finding


that maximizes


. We first explain how to compute a Bayesian score


based on


to measure how well


models the data. We then explain how


See D. M. Chickering, “Learn-


to go about searching the space of networks for the highest-scoring network. Like


ing Bayesian Networks is NP-


inference in Bayesian networks, it can be shown that for general graphs and input


Complete,” in


Learning from Data:


data, learning the structure of a Bayesian network is NP-hard.


Artificial Intelligence and Statistics


, D. Fisher and H.


J. Lenz, eds.,


We compute


using Bayes’ rule and the law of total probability:


Springer, 1996, pp. 121–130. D. M.


Chickering, D. Heckerman, and C.