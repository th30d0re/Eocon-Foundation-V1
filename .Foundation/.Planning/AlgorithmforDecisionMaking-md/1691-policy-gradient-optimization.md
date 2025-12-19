---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Policy Gradient Optimization
---

# Policy Gradient Optimization

_Source page: 271_



We can use estimates of the policy gradient to drive the search of the parameter


space toward an optimal policy. The previous chapter outlined methods for


estimating this gradient. This chapter explains how to use these estimates to


guide the optimization. We begin with gradient ascent, which simply takes steps


in the direction of the gradient at each iteration. Determining the step size is a


major challenge. Large steps can lead to faster progress to the optimum, but they


can overshoot. The natural policy gradient modifies the direction of the gradient


to better handle variable levels of sensitivity across parameter components. We


conclude with the trust region method, which starts in exactly the same way as


the natural gradient method to obtain a candidate policy. It then searches along


the line segment in policy space connecting the original policy to this candidate


to find a better policy.