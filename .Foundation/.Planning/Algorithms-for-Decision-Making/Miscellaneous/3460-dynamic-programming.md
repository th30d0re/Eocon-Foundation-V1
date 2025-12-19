---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Dynamic Programming
---

# Dynamic Programming

_Source page: 571_



Autonomous Agents and Multi-Agent


Systems


, vol. 17, no. 2, pp. 190–250,


2008.


The


dynamic programming


algorithm for Dec-POMDPs applies the Bellman backup


at each step and prunes dominated policies. This process is identical to dynamic


programming for POMGs except that each agent shares the same reward. Algo-


rithm 27.2 implements this procedure.


Algorithm 27.2.


Dynamic pro-


struct


DecPOMDPDynamicProgramming


gramming computes the optimal


# initial belief


joint policy


for a Dec-POMDP


# depth of conditional plans


, given an initial belief


and


end


horizon depth


. We can directly


use the POMG algorithm, as Dec-


function


solve


::


DecPOMDPDynamicProgramming


::


DecPOMDP


POMDPs are a special collabora-


R′


for


in


tive class of POMGs.


𝒫′