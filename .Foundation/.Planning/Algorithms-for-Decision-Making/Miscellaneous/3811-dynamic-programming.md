---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Dynamic Programming
---

# Dynamic Programming

_Source page: 626_



Neither forward search nor branch and bound remembers whether a state has


been previously visited; each wastes computational resources by evaluating these


states multiple times.


Dynamic programming


(algorithm E.4) avoids duplicate


effort by remembering when a particular subproblem has been previously solved.


Dynamic programming can be applied to problems in which an optimal solution


can be constructed from optimal solutions of its subproblems, a property called


optimal substructure


. For example, if the optimal sequence of actions from


to


goes through


, then the subpaths from


and from


to


are also optimal.


to


This substructure is shown in figure E.4.


Figure E.4. The sequence of states


1 2


1 2


1 2


on the left form an optimal path