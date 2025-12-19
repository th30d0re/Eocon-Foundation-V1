---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 576_



Dec-POMDPs are fully cooperative POMGs that model a team of agents work-


ing together toward a shared goal, each acting individually using only local


information.


Because determining a belief state is infeasible, as in POMGs, policies are


generally represented as conditional plans or controllers, allowing each agent


to map individual sequences of observations to individual actions.


Many subclasses of Dec-POMDPs exist, with different degrees of computa-


tional complexity.


Dynamic programming computes the value function iteratively, pruning dom-


inated policies as it iterates using a linear program.


Iterated best response computes a best utility-maximizing response policy for


a single agent at a time, iteratively converging to a joint equilibrium.


Heuristic search searches a fixed subset of policies at each iteration, guided by


a heuristic.


• Nonlinear programming can be used to generate controllers of a fixed size.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


27.7. summary


555


Algorithm 27.5. NLP computes the


struct


DecPOMDPNonlinearProgramming


optimal joint controller policy


for


# initial belief


a Dec-POMDP


, given an initial


# number of nodes for each agent


belief


and number of controller


end


nodes


for each agent. This gen-


eralizes the NLP solution in algo-


function


tensorform


::


DecPOMDP


rithm 23.5.


ℐ′


eachindex


𝒮′


eachindex


𝒜′


eachindex


𝒜i


for


𝒜i


in


𝒪′


eachindex


𝒪i


for


𝒪i


in


R′


for


in


in


joint


)]


T′


s′


for


in


in


joint


),


s′


in


O′


s′


for


in


joint


),


s′


in


in


joint


)]


return


ℐ′


𝒮′


𝒜′


𝒪′


R′


T′


O′


end


function


solve


::


DecPOMDPNonlinearProgramming


::


DecPOMDP


tensorform


collect


for


in


jointX


joint𝒜


joint𝒪


joint


),


joint


),


joint


x1


jointX


model


Model


Ipopt


Optimizer


@variable


model


jointX


])


@variable


model


],


]]


@variable


model


],


],


],


]]


@objective


model


Max


b⋅U


x1


])


@NLconstraint


model


, [


jointX


],


==


sum


prod


],


]]


for


in


sum


s′


sum


s′


sum


prod


],


],


],


x′


]]


for


in


x′


s′


for


x′


in


jointX


for


in


enumerate


joint𝒪


))


for


s′


in


))


for


in


enumerate


joint𝒜