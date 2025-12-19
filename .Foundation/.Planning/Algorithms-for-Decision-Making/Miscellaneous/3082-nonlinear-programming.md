---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Nonlinear Programming
---

# Nonlinear Programming

_Source page: 500_



The policy improvement problem can be framed as a single, large,


nonlinear pro-


gramming


formulation (algorithm 23.5) that involves simultaneously optimizing


C.


and


across all nodes.


This formulation allows general-purpose solvers to


Amato,


D. S.


Bernstein,


and S. Zilberstein, “Optimizing


be applied. The nonlinear programming method directly searches the space of


Fixed-Size Stochastic Controllers


controllers to maximize the utility of a given initial belief while satisfying the


for POMDPs and Decentralized


POMDPs,”


Autonomous Agents and


Bellman expectation equation, equation (23.1). There is no alternating between


Multi-Agent Systems


, vol. 21, no. 3,


policy evaluation and policy improvement steps, and the controller node count


pp. 293–320, 2010.


remains fixed.


We use


to denote the initial node corresponding to the given initial belief


The optimization problem is then


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


23.3. nonlinear programming


479


Algorithm 23.4. The pruning step


function


prune!


::


ControllerPolicy


prevX


of policy iteration. It reduces the


number of nodes in the current


newX


removeX


setdiff


prevX