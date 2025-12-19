---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Linear Systems with Quadratic Reward
---

# Linear Systems with Quadratic Reward

_Source page: 169_



18


This section assumes that the


So far, we have assumed discrete state and action spaces. This section relaxes


problem is undiscounted and finite


this assumption, allowing for continuous, vector-valued states and actions. The


horizon, but these equations can be


18


Bellman optimality equation for discrete problems can be modified as follows:


easily generalized.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


148


chapter 7. exact solution methods


Algorithm 7.10.


A method for


struct


LinearProgramFormulation


end


solving a discrete MDP using a


linear program formulation. For


function


tensorform


::


MDP


convenience in specifying the lin-


ear program, we define a func-


𝒮′


eachindex


tion for converting an MDP into


𝒜′


eachindex


R′


for


in


in


its tensor form, where the states


T′


s′


for


in


in


s′


in


and actions consist of integer in-


return


𝒮′


𝒜′


R′


T′


dices, the reward function is a ma-


end


trix, and the transition function is


a three-dimensional tensor. It uses


solve


::


MDP


solve


LinearProgramFormulation


(),


the


JuMP.jl


package for mathemat-


ical programming. The optimizer


function


solve


::


LinearProgramFormulation


::


MDP


is set to use


GLPK.jl


, but others can


tensorform


be used instead. We also define the


model


Model