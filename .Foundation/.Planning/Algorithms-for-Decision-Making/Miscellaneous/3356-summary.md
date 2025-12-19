---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 550_



MGs are an extension of MDPs to multiple agents or an extension of simple


games to sequential problems. In these problems, multiple agents compete


and individually receive rewards over time.


The Nash equilibrium can be formulated for MGs, but it must now consider


all actions for all agents in all states.


The problem of finding a Nash equilibrium can be formulated as a nonlinear


optimization problem.


We can generalize fictitious play to MGs by using a known transition function


and incorporating estimates of action values.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


25.7. summary


529


Algorithm 25.9. Nash


-learning


mutable struct


NashQLearning


for an agent


in an MG


. The al-


# Markov game


gorithm performs joint-action


# agent index


learning to learn a state-action


# state-action value estimates


value function for all agents. A sim-


# history of actions performed


ple game is built with


, and we


end


compute a Nash equilibrium using


function


NashQLearning


::


MG


algorithm 24.5. The equilibrium


is then used to update the value


Dict


((


=>


0.0 for


in


in


in


joint


))


function. This implementation also


Dict


((


=>


1.0 for


in


in


joint


))


uses a variable learning rate pro-


return


NashQLearning


portional to the number of times


end


state-joint-action pairs are visited,


which is stored in


. In addition,


function


πi


::


NashQLearning


)(


it uses


-greedy exploration to en-


πi


πi


πi


πi


sure that all states and actions are


𝒜i


πi


],


explored.


NashEquilibrium


()


SimpleGame


->


for


in


])


solve


sum


for


in


joint


))


πi′


ai


length


𝒜i


](


ai


return


SimpleGamePolicy


ai


=>


πi′


ai


for


ai


in


𝒜i


end


function


update!


πi


::


NashQLearning


s′


πi


πi


πi


πi


πi


πi


πi


πi


πi


NashEquilibrium


()


SimpleGame


a′


->


s′


a′


for


in


])


solve


πi


+=


sqrt


])


for


in


πi


+=


)[


utility


])


end


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


530


chapter 25. sequential problems


Gradient ascent approaches iteratively improve a stochastic policy, and they


do not need to assume a model.


Nash


-learning adapts traditional


-learning to multiagent problems and


involves solving for a Nash equilibrium of a simple game constructed from


models of the other players.