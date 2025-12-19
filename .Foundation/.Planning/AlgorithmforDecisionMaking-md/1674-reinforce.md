---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: REINFORCE
---

# REINFORCE

_Source page: 267_



as introduced by


Qualitatively, when considering the gradient contribution of state-action pairs,


R. J. Williams, “Simple Statistical


Gradient-Following


Algorithms


what we really care about is the relative value of one action over another. If all


for Connectionist Reinforcement


actions in a particular state produce the same high value, there is no real signal


Learning,”


Machine Learning


, vol. 8,


pp. 229–256, 1992.


in the gradient, and baseline subtraction can zero that out. We want to identify


the actions that produce a higher value than others, regardless of the mean value


across actions.


An alternative to the action value is the


advantage