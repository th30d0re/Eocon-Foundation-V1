---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Linear Policies
---

# Linear Policies

_Source page: 441_



As discussed in section 19.3, the belief state in a problem with linear Gaussian


dynamics can be represented by a Gaussian distribution,


. If the reward


function is quadratic, then it can be shown that the optimal policy can be computed


exactly offline using a process that is often called


linear quadratic Gaussian


LQG


control. The optimal action is obtained in an identical manner as in section 7.8,


Our ability to simply use the


but the


computed using the linear Gaussian filter is treated as the true state.


mean of the distribution is another


With each observation, we simply use the filter to update our


and obtain an


instance of the


certainty equivalence


optimal action by multiplying


principle, originally introduced in


with the policy matrix from algorithm 7.11.


section 7.8.


Example 20.4 demonstrates this process.