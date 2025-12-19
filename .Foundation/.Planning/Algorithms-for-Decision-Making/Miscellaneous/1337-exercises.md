---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 199_



Exercise 8.1.


The value function approximation methods presented in this chapter have


mostly assumed continuous state spaces. The hex world problem, appendix F.1, is discrete,


but most of its states can be mapped to two-dimensional locations. It does, however,


have an additional terminal state that produces zero reward, which does not have a two-


dimensional location. How can one modify the continuous value function approximation


methods in this chapter to handle such a state?


Solution:


The hex world problem has the agent navigate through a two-dimensional hexag-


onal grid. However, the agent can enter a single terminal state from one of several grid


hexes. This single terminal state presents a challenge for value function approximation


methods, which often rely on proximity to infer a state’s value.


While the terminal state could be projected to the same state space as the other states,


perhaps far away, this hack would nevertheless force a form of proximity into the terminal


state’s value calculation. Selecting a single position for a state that should be equidistant


to multiple predecessor states introduces bias.


One alternative is to treat the terminal state as a special case. The kernel function could


be modified to produce infinite distance between the terminal state and any other states.


Another option is to adjust the problem to have a terminal state for every hex that


produces a terminal reward. Each terminal state can be coincident with its predecessor


state, but offset in an additional dimension. This transformation maintains proximity at


the expense of additional states.


Exercise 8.2.


A tabular representation is a special case of linear approximate value func-


tions. Show how, for any discrete problem, a tabular representation can be framed as a


linear approximate value function.


Solution:


Consider a discrete MDP with


states


actions


. A tabular repre-


1:


and


1:


sentation associates a value with each state or state-action pair. We can recover the same


behavior using a linear approximate value function. We associate an indicator function


with each state or state-action pair, whose value is


when the input is the given state or


state-action pair and


otherwise:


if