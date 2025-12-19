---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Reward-to-Go
---

# Reward-to-Go

_Source page: 259_



The likelihood ratio policy gradient method is unbiased but has high variance.


Example 11.4 reviews bias and variance. The variance generally increases sig-


nificantly with rollout depth due to the correlation between actions, states, and


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


238


chapter 11. policy gradient estimation


Example 11.3. Applying the likeli-


Consider the single-step, single-state problem from example 11.1. Suppose


hood ratio trick to estimate a policy


we have a stochastic policy


that samples its action according to a Gaussian


gradient in a simple problem.


distribution


, where


is the variance.


log