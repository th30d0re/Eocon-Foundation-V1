---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Branch and Bound
---

# Branch and Bound

_Source page: 478_



The


branch and bound


technique originally introduced in the context of MDPs can


be extended to POMDPs as well. The same algorithm in section 9.4 can be used


without modification (see example 22.3), relying on the appropriate lookahead


implementation to update beliefs and account for the observations. The efficiency


of the algorithm still depends on the quality of the upper and lower bounds for


pruning.


Although we can use domain-specific heuristics for the upper and lower


bounds, as we did in the fully observed case, we can alternatively use one of


the methods introduced in the previous chapter for discrete state spaces. For


example, we can use the fast informed bound for the upper bound and point-


based value iteration for the lower bound. So long as the lower bound


and


upper bound


are true lower and upper bounds, the result of the branch and


bound algorithm will be the same as the forward search algorithm with


as the


approximate value function.


Example 22.3. An application of


In this example, we apply branch and bound to the crying baby problem


branch and bound to the crying


with a depth of


. The upper bound comes from the fast informed bound,


baby problem.


and the lower bound comes from point-based value iteration. We compute


the action from belief