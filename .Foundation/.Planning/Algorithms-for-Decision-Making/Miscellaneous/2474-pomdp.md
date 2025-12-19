---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 403_



ture for POMDPs. We will use


# discount factor


the


TRO


field to sample the next


# state space


state, reward, and observation


# action space


given the current state and action:


# observation space


# transition function


s′


TRO


. A compre-


# reward function


hensive package for specifying and


# observation function


solving POMDPs is provided by


TRO


# sample transition, reward, and observation


M. Egorov, Z. N. Sunberg, E. Bala-


end


ban, T. A. Wheeler, J. K. Gupta, and


M. J. Kochenderfer, “POMDPs.jl: A


Framework for Sequential Decision


Making Under Uncertainty,”


Jour-


A kind of inference known as


recursive Bayesian estimation


can be used to update


nal of Machine Learning Research


our belief distribution over the current state, given the most recent action and


vol. 18, no. 26, pp. 1–5, 2017. In


observation. We use


to represent the probability (or probability density for


mathematical writing, POMDPs


are sometimes defined in terms of


continuous state spaces) assigned to state


. A particular belief


belongs to a


a tuple consisting of the various


belief space


, which contains all possible beliefs.


components of the MDP, written


as


When the state and observation spaces are finite, we can use a


discrete state filter


to perform this inference exactly. Beliefs for problems with discrete state spaces


can be represented using categorical distributions, where a probability mass is


assigned to each state. This categorical distribution can be represented as a vector


of length