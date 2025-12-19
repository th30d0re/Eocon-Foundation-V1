---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Stochastic Mixing Iterative Learning
---

# Stochastic Mixing Iterative Learning

_Source page: 380_



ficient Reductions for Imitation


Learning,” in


International Confer-


Sequential interactive methods can also iteratively build up a policy by stochas-


ence on Artificial Intelligence and


Statistics (AISTATS)


, 2010.


tically mixing in newly trained policies. One such method is


stochastic mixing


We do not have an explicit rep-


iterative learning


SMILe


) (algorithm 18.3).


It uses behavioral cloning in every


resentation of


. Evaluating


iteration but mixes the newly trained policy with the previous ones.


requires interactively querying the


We start with the expert policy,


In each iteration, we execute the


expert, as done in the previous sec-


tion.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


18.3. stochastic mixing iterative learning


359


Algorithm 18.2.


The DAgger


struct


DataSetAggregation


method of data set aggregation


# problem with unknown reward function


for learning a stochastic parame-


bc


# behavioral cloning struct


terized policy from expert demon-


k_max


# number of iterations


strations. This method takes an ini-


# number of rollouts per iteration


tial data set of state-action tuples


# rollout depth


# initial state distribution


a stochastic parameterized policy


πE


# expert


πθ


, an MDP


that defines


πθ


# parameterized policy


a transition function, and an ini-


end


tial state distribution


. Behavioral


cloning (algorithm 18.1) is used in


function


optimize


::


DataSetAggregation


each iteration to improve the pol-


bc


k_max


bc


k_max


icy.


πE


πθ


πE


πθ


An expert policy


πE


labels tra-


optimize


bc


jectories sampled from the latest


for


in 2


k_max


learned policy to augment the data


for


in 1


set. The original paper generated


rand


trajectories by stochastically mix-


for


in 1


ing in the expert policy. This imple-


push!


, (


πE


)))


mentation is thus the original DAg-


rand


πθ


))


ger with an extreme mixing value


rand


))


of zero.


end


In practice, an expert policy


end


would not exist, and calls to this


optimize


bc


policy would be replaced with


end


queries to a human expert.


return


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


360


chapter 18. imitation learning


Example 18.3. DAgger applied to


Consider using DAgger to train a policy on the mountain car problem where


the mountain car problem, with it-


the reward is not observed. We use an expert policy that accelerates in the


erations running from top to bot-


tom. Trajectories accumulate in the


direction of travel. In this example, we train a policy using the following


data set over time. The behavior of


features:


the agent improves with each itera-