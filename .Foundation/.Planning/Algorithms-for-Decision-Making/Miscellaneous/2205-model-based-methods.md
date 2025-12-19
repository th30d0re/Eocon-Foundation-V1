---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Model-Based Methods
---

# Model-Based Methods

_Source page: 339_



This chapter discusses both maximum likelihood and Bayesian approaches for


learning the underlying dynamics and reward through interaction with the envi-


ronment. Maximum likelihood methods involve counting state transitions and


recording the amount of reward received to estimate the model parameters. We


will discuss a few approaches for planning using models that are continuously


updated. Even if we solve the estimated problem exactly, we generally have to


rely on heuristic exploration strategies to arrive at a suitable solution. Bayesian


methods involve computing a posterior distribution over model parameters. Solv-


ing for the optimal exploration strategy is generally intractable, but we can often


obtain a sensible approximation through posterior sampling.