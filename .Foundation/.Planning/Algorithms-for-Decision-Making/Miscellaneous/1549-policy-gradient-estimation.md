---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Policy Gradient Estimation
---

# Policy Gradient Estimation

_Source page: 253_



An additional resource on this


The previous chapter discussed several ways to go about directly optimizing the


topic is M. C. Fu, “Gradient Estima-


parameters of a policy to maximize expected utility. In many applications, it is


tion,” in


Simulation


, S. G. Hender-


often useful to use the gradient of the utility with respect to the policy parameters


son and B. L. Nelson, eds., Elsevier,


2006, pp. 575–616.


to guide the optimization process. This chapter discusses several approaches


to estimating this gradient from trajectory rollouts.


A major challenge with


this approach is the variance of the estimate due to the stochastic nature of the


trajectories arising from both the environment and our exploration of it. The next


chapter will discuss how to use these algorithms to estimate gradients for the


purpose of policy optimization.