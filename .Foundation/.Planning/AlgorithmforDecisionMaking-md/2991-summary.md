---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 486_



A simple online strategy is to perform a one-step lookahead, which considers


each action taken from the current belief and estimates its expected value using


an approximate value function.


Forward search is a generalization of lookahead to arbitrary horizons, which


can lead to better policies, but its computational complexity grows exponen-


tially with the horizon.


Branch and bound is a more efficient version of forward search that can avoid


searching certain paths by placing upper and lower bounds on the value


function.


Sparse sampling is an approximation method that can reduce the computa-


tional burden of iterating over the space of all possible observations.


Monte Carlo tree search can be adapted to POMDPs by operating over histories


rather than states.


Determinized sparse tree search uses a special form of particle belief that


ensures that observations are determinized, greatly reducing the search tree.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


22.8. summary


465


Algorithm 22.4. An implementa-


struct


GapHeuristicSearch


tion of heuristic search that uses


# problem


bounds, a gap criterion, and ini-


Ulo


# lower bound on value function


tial lower and upper bounds on


Uhi


# upper bound on value function


the value function. We update a


# gap threshold


dictionary


Ulo


and


Uhi


to main-


k_max


# maximum number of simulations


d_max


# maximum depth


tain the lower and upper bounds


end


on the value function as spe-


cific beliefs. At belief


, the gap


function


heuristic_search


::


GapHeuristicSearch


Ulo


Uhi


is


Uhi


Ulo


. Exploration


stops when the gap is smaller than


the threshold


or the maximum


Dict


((


=>


update


for


in


product


))


depth


d_max


is reached. A maxi-


merge


Dict


(()


=>


copy


)))


mum number of iterations


k_max


for


ao


b′


in


is allotted to search.


if


haskey


Uhi


b′


Ulo


b′


],


Uhi


b′


Ulo


b′


),


Uhi


b′


end


end


if


==


||


Uhi


Ulo


return


end


argmax


->


lookahead


b′


->


Uhi


b′


],


),


argmax


->


Uhi


[(


)]]


Ulo


[(