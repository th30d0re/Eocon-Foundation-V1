---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMCP
---

# POMCP

_Source page: 479_



and show its convergence. D. Sil-


algorithm is that the counts and values are associated with


histories


instead of


ver and J. Veness, “Monte-Carlo


states. A history is a sequence of past actions and observations. For example, if


Planning in Large POMDPs,” in


Advances in Neural Information Pro-


we have two actions


, then a possible


and two observations


and


and


cessing Systems (NIPS)


, 2010.


history could be the sequence


. During the execution of the


Monte Carlo tree search can be im-


algorithm, we update the value estimates


and counts


for a set of


plemented with a POMDP rollout


history-action pairs.


policy that operates on beliefs, or


on an MDP rollout policy that op-


The histories associated with


and


may be organized in a tree similar to


erates on states. Random policies


the one in figure 22.2. The root node represents the empty history starting from


are commonly used.


There are many variations of the


the initial belief state


. During the execution of the algorithm, the tree structure


basic algorithm introduced here,


expands. The layers of the tree alternate between action nodes and observation


including some that incorporate as-


nodes. Associated with each action node are values


and


, where the


pects of double progressive widen-


ing, discussed in section 9.6. Z. N.


history is determined by the path from the root node. As with the MDP version,


Sunberg and M. J. Kochenderfer,


when searching down the tree, the algorithm takes the action that maximizes


“Online Algorithms for POMDPs


with Continuous State, Action, and


log


Observation Spaces,” in


Interna-