---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Dynamic Programming
---

# Dynamic Programming

_Source page: 562_



The approach taken in the previous section for computing a Nash equilibrium is


typically extremely computationally expensive because the actions correspond


to all possible conditional plans to some depth. We can adapt the value iteration


approach for POMDPs (section 20.5), where we iterated between expanding the


depth of the set of considered conditional plans and pruning suboptimal plans.


While the worst-case computational complexity is the same as that of the full


expansion of all policy trees, this incremental approach can lead to significant


savings.


Algorithm 26.4 implements this dynamic programming approach. It begins


by constructing all one-step plans. We prune any plans that are dominated by


another plan, and we then expand all combinations of one-step plans to produce


two-step plans. This procedure of alternating between expansion and pruning is


repeated until the desired horizon is reached.


The pruning step eliminates all dominated policies. A policy


belonging to


an agent


can be pruned if there exists another policy


that always performs at


least as well as


. Although computationally expensive, this condition can be


checked by solving a linear program. This process is related to controller node


pruning in POMDPs (algorithm 23.4).


It would be computationally intractable to solve a separate linear program for


every possible combination of the other agent’s policies


. Instead, we can take


a much more efficient approach that will never prune an optimal policy but may


not be able to prune all suboptimal policies. A policy


is dominated by


if


there is no


between other joint policies


and states


such that