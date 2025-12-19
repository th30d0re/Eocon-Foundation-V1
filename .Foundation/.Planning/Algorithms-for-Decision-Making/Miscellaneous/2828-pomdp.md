---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 468_



the utilities to


, but if we want to


FreudenthalTriangulation


length


),


represent an upper bound, then


belief_vertices


we would need to initialize those


Dict


=>


0.0 for


in


utilities appropriately. We define a


return


TriangulatedPolicy


function to estimate the utility of


end


a given belief using interpolation.


We can extract a policy using


function


utility


::


TriangulatedPolicy


greedy lookahead. The Freuden-


belief_simplex


thal


triangulation


structure


is


return


sum


λi


for


λi


in


zip


))


passed the dimensionality and


end


granularity at construction. The


FreudenthalTriangulations.jl


::


TriangulatedPolicy


)(


greedy


).


package provides the function


belief_vertices


, which returns


, given a particular triangulation.


It also provides


belief_simplex


which returns the set of enclosing


points and weights for a belief.


Algorithm 21.16.


Approximate


struct


TriangulatedIteration


value iteration with


k_max


itera-


# granularity


tions using a triangulated policy


k_max


# maximum number of iterations


with granularity


. At each itera-


end


tion, we update the utilities asso-


ciated with the beliefs in


using


function


solve


::


TriangulatedIteration


TriangulatedPolicy


greedy one-step lookahead with


utility


triangulated utilities.


for


in 1


k_max


U′


greedy


).


for


in


for


u′


in


zip


U′


u′


end


end


return


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


21.10. summary


447


Policy


Value Function


manufacture


examine


0.2


0.2


failed components


failed components


interrupt


0.8


0.8


replace


0.4


0.4


0.6


0.6


0.6


0.6


failed component


failed component


0.4


0.4


0.8


0.8


0.2


0.2


0.2


0.6


0.8


0.2


0.6


0.8


0.4


0.4


failed components


failed components


Figure 21.10. The policy and value


function for the maintenance prob-


lem with granularity


10


af-