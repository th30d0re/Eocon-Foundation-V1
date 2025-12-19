---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Triangulated Value Functions
---

# Triangulated Value Functions

_Source page: 467_



13


H. Freudenthal, “Simplizialzer-


As discussed in section 20.1, a POMDP can be converted to a belief-state MDP.


legungen von Beschränkter Flach-


The state space in that belief-state MDP is continuous, corresponding to the


heit,”


Annals of Mathematics


, vol. 43,


space of possible beliefs in the original POMDP. We can approximate the value


pp. 580–582, 1942. This triangu-


lation method was applied to


function in a way similar to what was described in chapter 8 and then apply a


POMDPs in W. S. Lovejoy, “Com-


dynamic programming algorithm such as value iteration to the approximation.


putationally Feasible Bounds for


This section discusses a particular kind of local value function approximation


Partially Observed Markov De-


cision Processes,”


Operations Re-


13


that involves


Freudenthal triangulation


over a discrete set of belief points


. This


search


, vol. 39, no. 1, pp. 162–175,


triangulation allows us to interpolate the value function at arbitrary points in the


1991.


belief space. As with the sawtooth representation, we use a set of belief-utility


14


FreudenthalTriangulations.jl


pairs