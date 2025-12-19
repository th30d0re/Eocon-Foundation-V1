---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Policy Validation
---

# Policy Validation

_Source page: 303_



The methods presented in the earlier chapters show how to construct an optimal


or approximately optimal solution with respect to a model of the dynamics and


reward. However, before deploying a decision-making system in the real world,


it is generally desirable to validate in simulation that the behavior of the resulting


policy is consistent with what is actually desired. This chapter discusses various


A more extensive discussion is


analytical tools for validating decision strategies.


We will start by discussing how


provided by A. Corso, R. J. Moss,


to go about evaluating performance metrics. Accurately computing such metrics


M. Koren, R. Lee, and M. J. Kochen-


can be computationally challenging, especially when they pertain to rare events


derfer, “A Survey of Algorithms for


Black-Box Safety Validation,”


Jour-


such as failures. We will discuss methods that can help address computational


nal of Artificial Intelligence Research


efficiency. It is important that our systems be robust to differences between the


vol. 72, pp. 377–428, 2021.


models that we use for analysis and the real world. This chapter suggests methods


for analyzing robustness. Fundamental to the design of many decision-making


systems is the trade-off between multiple objectives, and we will outline ways of


analyzing these trade-offs. The chapter concludes with a discussion of adversarial


analysis, which can be used for finding the most likely failure trajectory.