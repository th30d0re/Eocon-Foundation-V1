---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Performance Metric Evaluation
---

# Performance Metric Evaluation

_Source page: 303_



Once we have a policy, we are often interested in evaluating it with respect to


various


performance metrics


. For example, suppose that we constructed a collision


avoidance system—either through some form of optimization of a scalar reward


Other safety risk metrics are


function or just heuristically, as discussed in example 14.1—and we want to


discussed by I. L. Johansen and


assess its safety by computing the probability of collision when following our


M. Rausand, “Foundations and


policy.


Or, if we created a policy for constructing investment portfolios, we might


Choice of Risk Metrics,”


Safety Sci-


ence


, vol. 62, pp. 386–399, 2014.


be interested in understanding the probability that our policy will result in an


extreme loss or what the expected return may be.


282


chapter 14. policy validation


For the moment, we will consider a single metric


, evaluated on a policy


Often, this metric is defined as the expectation of a trajectory metric


, evaluated


traj


on trajectories