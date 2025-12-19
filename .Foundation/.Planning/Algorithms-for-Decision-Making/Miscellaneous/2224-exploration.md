---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exploration
---

# Exploration

_Source page: 343_



Regardless of the update scheme, some form of exploration strategy generally


must be followed to avoid the pitfalls of pure exploitation mentioned in the pre-


vious chapter. We can adapt the exploration algorithms presented in that chapter


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


322


chapter 16. model-based methods


Algorithm 16.5.


The prioritized


struct


PrioritizedUpdate


sweeping algorithm maintains a


# number of updates


priority queue


pq


of states that de-


pq


# priority queue


termines which are to be updated.


end


With each update, we set the pre-


vious state to have infinite prior-


function


update!


planner


::


PrioritizedUpdate


model


pq


model


model


planner


pq


ity. We then perform


Bellman up-


model


model


dates of the value function


at the


highest-priority states.


backup


model


for


s⁻


in


for


a⁻


in


n_sa


sum


s⁻


a⁻


s′


for


s′


in


if


n_sa


s⁻


a⁻


n_sa


priority


abs


if


priority


pq


s⁻


max


get


pq


s⁻


0.0


),


priority


end


end


end


end


return


planner


end


function


update!


planner


::


PrioritizedUpdate


model


s′


planner


pq


Inf


for


in 1


planner


if


isempty


planner


pq


break


end


update!


planner


model


dequeue!


planner


pq


))


end


return


planner


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


16.3. exploration


323


for use in multistate problems. Algorithm 16.6 provides an implementation of


the


-greedy exploration strategy.


Algorithm 16.6.


The


-greedy


function


::


EpsilonGreedyExploration


)(


model


exploration strategy for maximum


model


likelihood


model


estimates.


It


if


rand


()


chooses a random action with


return


rand


probability


; otherwise, it uses


end


the model to extract the greedy


lookahead


model


action.


return


argmax


->


),


end


A limitation of the exploration strategies discussed in the previous chapter is


that they do not reason about exploring actions from states besides the current


one. For instance, we might want to take actions that bring ourselves into an


area of the state space that has not been explored. Several algorithms have been


suggested for addressing this issue, which also provide probabilistic bounds on


M. Kearns and S. Singh, “Near-


the quality of the resulting policy after a finite number of interactions.


Optimal Reinforcement Learning


One such algorithm is known as