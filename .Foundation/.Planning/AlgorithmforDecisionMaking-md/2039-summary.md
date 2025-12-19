---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 317_



Performance metrics for policies may be evaluated using the dynamic program-


ming techniques discussed in earlier chapters or through sampling rollouts.


We can assess our confidence in our performance metric evaluations using stan-


dard error, confidence intervals, or one of the Bayesian approaches discussed


earlier.


Estimating the probability of rare events can be done more efficiently using a


method called importance sampling.


Importance sampling involves sampling from an alternative distribution and


weighting the results appropriately.


Because the model used for optimization may be an inaccurate representation of


the real world, it is important to study the sensitivity of our policy to modeling


assumptions.


Robust dynamic programming can help improve robustness to model uncer-


tainty by optimizing with respect to a set of different transition and reward


models.


Trade analysis can help us determine how to balance multiple performance


objectives when optimizing a policy.


Adversarial analyses involve an adversary that chooses the state to which we


transition at each step so as to minimize our objective while maximizing the


likelihood of the trajectory.