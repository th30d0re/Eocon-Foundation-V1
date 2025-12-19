---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Nonlinear Programming
---

# Nonlinear Programming

_Source page: 573_



C.


Amato,


D. S.


Bernstein,


and S. Zilberstein, “Optimizing


We can use


nonlinear programming


NLP


) (algorithm 27.5) to find an optimal joint


Fixed-Size Stochastic Controllers


controller policy representation of a fixed size.


This method generalizes the NLP


for POMDPs and Decentralized


POMDPs,”


Autonomous Agents and


approach for POMDPs from section 23.3.


Multi-Agent Systems


, vol. 21, no. 3,


pp. 293–320, 2010.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


552


chapter 27. collaborative agents


Algorithm


27.4.


Memory-


struct


DecPOMDPHeuristicSearch


bounded heuristic search uses


# initial belief


a heuristic function to search


# depth of conditional plans


the space of conditional plans


π_max


# number of policies


for a Dec-POMDP


. The


solve


end


function tries to maximize the


function


solve


::


DecPOMDPHeuristicSearch


::


DecPOMDP


value at an initial belief


for joint


conditional plans of depth


. The


π_max


π_max


explore


function generates a belief


R′


for


in


steps into the future by taking


𝒫′