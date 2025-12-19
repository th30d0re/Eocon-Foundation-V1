---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Branch and Bound
---

# Branch and Bound

_Source page: 207_



Branch and bound


(algorithm 9.3) attempts to avoid the exponential computational


complexity of forward search. It prunes branches by reasoning about bounds


on the value function. The algorithm requires knowing a lower bound on the


value function


and an upper bound on the action value function


The lower bound is used to evaluate the states at the maximum depth. This lower


bound is propagated upward through the tree through Bellman updates. If we


find that the upper bound of an action at a state is lower than the lower bound


of a previously explored action from that state, then we need not explore that


action, allowing us to


prune


the associated subtree from consideration.


Branch and bound will give the same result as forward search, but it can be


more efficient depending on how many branches are pruned. The worst-case


complexity of branch and bound is still the same as forward search. To facilitate


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


186


chapter 9. online planning


Figure 9.2. Forward search applied


Depth


Depth


to the hex world problem with four


maximum depths. The search can


visit a node multiple times. The ac-


tions and colors for visited states


were chosen according to the shal-


lowest, highest-value node in the


Depth


Depth


search tree for that state. The ini-


tial state has an additional black


border.


10


10


Algorithm 9.3.


The branch and


struct


BranchAndBound


bound algorithm for finding an


# problem


approximately optimal action on-


# depth


line for a discrete MDP


from a


Ulo


# lower bound on value function at depth d


current state


. The search is per-


Qhi


# upper bound on action value function


formed to depth


with value func-


end


tion lower bound


Ulo


and action


function


branch_and_bound


Ulo


Qhi


value function upper bound


Qhi


if


The returned named tuple consists


return


nothing


Ulo


))


of the best action


and its finite-


end


horizon expected value


. This al-


U′


branch_and_bound


-1


Ulo


Qhi


).


gorithm is also used for POMDPs.


best


nothing


=-


Inf


for


in


sort


by


->


Qhi


),


rev


true


if


Qhi


best


return


best


# safe to prune


end


lookahead


U′


if


best


best


end


end


return


best


end


::


BranchAndBound


)(


branch_and_bound


Ulo


Qhi


).


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


9.5. sparse sampling


187


pruning, actions are traversed in descending order by upper bound. Tighter


bounds will generally result in more pruning, as shown in example 9.2.


Example 9.2. Branch and bound


Consider applying branch and bound to the mountain car problem. We can


applied to the mountain car prob-


use the value function of a heuristic policy for the lower bound


, such as


lem (appendix F.4). Branch and


bound can achieve a significant


a heuristic policy that always accelerates in the direction of motion. For our


speedup over forward search.


upper bound