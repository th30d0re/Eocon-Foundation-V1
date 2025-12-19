---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Nash Equilibrium
---

# Nash Equilibrium

_Source page: 559_



As with simple games and MGs, a


Nash equilibrium


for a POMG is when all agents


act according to a best response policy to each other, such that no agents have


an incentive to deviate from their policy. Nash equilibria for POMGs tend to


be incredibly computationally difficult to solve. Algorithm 26.3 computes a


step Nash equilibrium for a POMG. It enumerates all of its possible


-step joint


conditional plans to construct a simple game, as shown in example 26.4. A Nash


equilibrium for this simple game is also a Nash equilibrium for the POMG.


The simple game has the same agents as the POMG. There is a joint action


in the simple game for every joint conditional plan in the POMG. The reward


received for each action is equal to the utilities under the joint conditional plan in


the POMG. A Nash equilibrium of this constructed simple game can directly be


applied as a Nash equilibrium of the POMG.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


538


chapter 26. state uncertainty


Algorithm 26.3. A Nash equilib-


struct


POMGNashEquilibrium


rium is computed for a POMG


# initial belief


with initial state distribution


by


# depth of conditional plans


creating a simple game of all con-


end


ditional plans to some depth


. We


solve for a Nash equilibrium in this


function


create_conditional_plans


simple game using algorithm 24.5.


[[


ConditionalPlan


ai


for


ai


in


]]


for


in


For simplicity, we select the most


for


in 1


probable joint policy. Alternatively,


expand_conditional_plans


we can randomly select the joint


end


policy at the start of execution.


return


end


function


expand_conditional_plans


return


[[


ConditionalPlan


ai


Dict


oi


=>


πi


for


oi


in


]))


for


πi


in


for


ai


in


]]


for


in


end


function


solve


::


POMGNashEquilibrium


::