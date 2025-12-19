---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Point Selection
---

# Point Selection

_Source page: 462_



Algorithms like point-based value iteration and sawtooth iteration require a set


of beliefs


. We want to choose


so that there are more points in the relevant


areas of the belief space; we do not want to waste computation on beliefs that


we are not likely to reach under our (hopefully approximately optimal) policy.


One way to explore the potentially reachable space is to take steps in the belief


space (algorithm 21.11). The outcome of the step will be random because the


observation is generated according to our probability model.


Algorithm 21.11.


A function for


function


randstep


::