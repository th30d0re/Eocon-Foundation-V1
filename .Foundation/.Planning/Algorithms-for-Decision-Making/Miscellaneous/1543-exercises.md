---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 248_



Exercise 10.1.


In Monte Carlo policy evaluation, how is the variance of the utility estimate


affected by the number of samples?


Solution:


The variance of Monte Carlo policy evaluation is the variance of the mean of


samples. These samples are assumed to be independent, and so the variance of the mean


is the variance of a single rollout evaluation divided by the sample size:


Var