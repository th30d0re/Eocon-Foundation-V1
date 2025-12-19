---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Randomized Updates
---

# Randomized Updates

_Source page: 340_



This approach is related to the


Dyna


approach suggested by R. S.


Recomputing an optimal policy with each state transition is typically computa-


Sutton, “Dyna, an Integrated Ar-


tionally expensive. An alternative is to perform a Bellman update on the estimated


chitecture for Learning, Planning,


and Reacting,”


SIGART Bulletin


model at the previously visited state, as well as a few randomly chosen states.


vol. 2, no. 4, pp. 160–163, 1991.


Algorithm 16.4 implements this approach.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


16.2. update schemes


319


Algorithm 16.1. A method for up-


mutable struct


MaximumLikelihoodMDP


dating the transition and reward


# state space (assumes 1:nstates)


model for maximum likelihood re-


# action space (assumes 1:nactions)


inforcement learning with discrete


# transition count N(s,a,s′)


state and action spaces. We incre-


# reward sum ρ(s, a)


ment


s′


after observing a


# discount


# value function


transition from


to


s′


after taking


planner


action


, and we add


to


end


The model also contains an esti-


mate of the value function


and


function


lookahead


model


::


MaximumLikelihoodMDP


a planner. This algorithm block


model


model


model


also includes methods for perform-


sum


model


])


ing backup and lookahead with re-


if


==


spect to this model.


return 0.0


end


model


s′


model


s′


return


sum


s′


s′


for


s′


in


end


function


backup


model


::


MaximumLikelihoodMDP


return


maximum


lookahead


model


for


in


model


end


function


update!


model


::


MaximumLikelihoodMDP


s′


model


s′


+=


model


+=


update!


model


planner


model


s′


return


model


end


Algorithm 16.2.


A method for


function


MDP


model


::


MaximumLikelihoodMDP


converting a maximum likelihood


model


model


model


model


model


model to an


MDP


problem.


similar


),


similar


for


in


for


in


sum


])


if


==


] .


0.0


0.0


else


end


end


end


return


MDP


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


320


chapter 16. model-based methods


Example 16.1. Applying maximum


We would like to apply maximum likelihood model estimation to the hex


likelihood estimation to the hex


world problem. The true transition matrices look like this:


world problem.


0.8


0.6


0.4


0.2


There are six transition matrices, one for each action. The rows correspond


to the current state, and the columns correspond to the next state. There


are


26


states. The intensity in the images relate to the probability of making


the corresponding transition. In a reinforcement learning context, we do


not know these transition probabilities ahead of time. However, we can


interact with the environment and record the transitions we observe. After


10


simulations of


10


steps each from random initial states, maximum likelihood


estimation results in the following matrices:


0.8


0.6


0.4


0.2


After