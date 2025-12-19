---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 564_



Exercise 26.1.


Show that a POMG generalizes both a POMDP and an MG.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


26.6. exercises


543


Example 26.5. Dynamic program-


Consider the multicaregiver crying baby problem solved by dynamic pro-


ming and a single pruning step


gramming. Initially, the policies at depth


are


for the multicaregiver crying baby


problem.


policies


agent


policies


agent


After the pruning step, the agent policies are


policies


agent


policies


agent


In this case, the pruning step finds the best joint policy. This approach signif-


icantly reduces the number of possible joint policies that the next iteration of


the algorithm needs to consider.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


544


chapter 26. state uncertainty


Solution:


For any POMDP, we can define a POMG with one agent


. States


are


identical, as are actions


= (


and observations


= (


. Thus, the state transition,


observation function, and rewards of the POMG directly follow. The Nash equilibrium


optimization has only one agent, so it results in a simple maximization of expected value,


which is identical to a POMDP.


For any MG, we can define a POMG with the same agents


, states


, joint actions


transitions


, and joint rewards


. The individual observations are assigned to be states


. The observation function then deterministically provides each agent with the true


state


) =


if


= (