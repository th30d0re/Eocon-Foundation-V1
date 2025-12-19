---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Markov Decision Processes
---

# Markov Decision Processes

_Source page: 155_



In an MDP (algorithm 7.1), we choose action


based on observing state


at time


. We then receive a reward


. The


action space


is the set of possible actions,


and the


state space


is the set of possible states. Some of the algorithms assume


that these sets are finite, but this is not required in general. The state evolves


Figure 7.1. MDP decision network


diagram.


probabilistically based on the current state and action we take. The assumption


that the next state depends only on the current state and action and not on any


prior state or action is known as the


Markov assumption


An MDP can be represented using a decision network as shown in figure 7.1.


There are informational edges (not shown here) from


. The


1:


and


1:


to


utility function is decomposed into rewards


. We focus on


stationary


MDPs


1:


in which


and


do not vary with time. Stationary


MDPs can be compactly represented by a dynamic decision diagram as shown


in figure 7.2. The


state transition model


represents the probability of


transitioning from state


to


after executing action


. The


reward function


Figure 7.2. Stationary MDP deci-


represents the expected reward received when executing action


from state


sion network diagram. All MDPs


have this general structure.


134


chapter 7. exact solution methods


For example, if the reward de-


The reward function is a deterministic function of


and


because it represents


pends on the next state as given


an expectation, but rewards may be generated stochastically in the environment


by


, then the expected re-


or even depend on the resulting next state.


Example 7.1 shows how to frame a


ward function would be


collision avoidance problem as an MDP.


) =


Example 7.1. Aircraft collision


The problem of aircraft collision avoidance can be formulated as an MDP. The


avoidance framed as an MDP.


states represent the positions and velocities of our aircraft and the intruder


Many other real-world applica-


tions are discussed in D. J. White,


aircraft, and the actions represent whether we climb, descend, or stay level.


“A Survey of Applications of


We receive a large negative reward for colliding with the other aircraft and a


Markov Decision Processes,”


Jour-


small negative reward for climbing or descending.


nal of the Operational Research Soci-


ety


, vol. 44, no. 11, pp. 1073–1096,


Given knowledge of the current state, we must decide whether an avoid-


1993.


ance maneuver is required. The problem is challenging because the positions


of the aircraft evolve probabilistically, and we want to make sure that we


start our maneuver early enough to avoid collision, but late enough so that


we avoid unnecessary maneuvering.


Algorithm 7.1. Data structure for


struct


MDP


an MDP. We will use the


TR


field


# discount factor


later to sample the next state and


# state space


reward given the current state


# action space


and action:


s′


TR


. In


# transition function


# reward function


mathematical writing, MDPs are


TR


# sample transition and reward


sometimes defined in terms of


end


a tuple consisting of the various


components of the MDP, written


The rewards in an MDP are treated as components in an additively decomposed


utility function. In a


finite horizon


problem with


decisions, the utility associated


with a sequence of rewards


1:


is simply