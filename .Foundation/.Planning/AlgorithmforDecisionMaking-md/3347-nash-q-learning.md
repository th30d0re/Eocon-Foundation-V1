---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Nash Q-Learning
---

# Nash Q-Learning

_Source page: 548_



Another learning-based approach is


Nash


-learning


(algorithm 25.9), which


J. Hu and M. P. Wellman, “Nash


borrows inspiration from


-learning (section 17.2).


The method maintains an


Q-Learning


for


General-Sum


estimate of the action value function, which is adapted as the agents react to each


Stochastic


Games,”


Journal


of


other’s changing policies. In the process of updating the action value function, it


Machine Learning Research


, vol. 4,


pp. 1039–1069, 2003.


computes a Nash equilibrium to model the behavior of the other agents.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


25.6. nash q-learning


527


Algorithm 25.8. Gradient ascent


mutable struct


MGGradientAscent


for an agent


of an MG


. The


# Markov game


algorithm incrementally updates


# agent index


its distributions of actions at vis-


# time step


ited states following gradient as-


Qi


# state-action value estimates


cent to improve the expected utility.


πi


# current policy


end


The projection function from algo-


rithm 23.6 is used to ensure that


function


MGGradientAscent


::


MG


the resulting policy remains a valid


probability distribution.


Qi


Dict


((


=>


0.0 for


in


in


joint


))


uniform


()


Dict


=>


SimpleGamePolicy


ai


=>


1.0 for


ai


in


])


for


in


return


MGGradientAscent


Qi


uniform


())


end


function


πi


::


MGGradientAscent


)(


𝒜i


πi


πi


],


πi


sqrt


πi′


ai


length


𝒜i


πi


πi


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


MGGradientAscent


s′


Qi


πi


πi


πi


πi


Qi


𝒜i


πi


],


jointπ


ai


Tuple


==


ai


for


in


sqrt


Qmax


maximum


Qi


s′


jointπ


ai


)]


for


ai


in


𝒜i


πi


Qi


+=


)[


Qmax


Qi


])


Qi


jointπ


ai


)]


for


ai


in


𝒜i


π′


πi


πi


](


ai


for


ai


in


𝒜i


project_to_simplex


π′


sqrt


))


πi


πi


πi


SimpleGamePolicy


ai


=>


for


ai


in


zip


𝒜i


))


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


528


chapter 25. sequential problems


An agent following Nash


-learning maintains an estimate of a joint action


value function


. This action value function is updated after every state


transition using a Nash equilibrium computed from a simple game constructed


from this value function. After a transition from


to


following the joint action


, we construct a simple game with the same number of agents and the same joint


action space, but the reward function is equal to the estimated value of


such


that