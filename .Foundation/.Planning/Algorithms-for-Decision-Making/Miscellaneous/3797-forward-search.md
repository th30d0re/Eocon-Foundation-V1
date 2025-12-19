---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Forward Search
---

# Forward Search

_Source page: 622_



Perhaps the simplest graph search algorithm is


forward search


(algorithm E.2),


The approximate value functions


which determines the best action to take from an initial state


by looking at all


in this chapter are expected to re-


possible action-state transitions up to a depth (or horizon)


. At depth


, the


turn


when in a state with no avail-


algorithm uses an estimate of the value of the state


The algorithm calls


able actions.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


e.4. branch and bound


601


Figure E.2. The graph for the


1 2


sliding tile puzzle in figure E.1 can


be represented as a tree search


problem. The search begins at the


root node and flows down the tree.


In this case, a path can be traversed


1 2


1 2


1 2


to the desired terminal state.