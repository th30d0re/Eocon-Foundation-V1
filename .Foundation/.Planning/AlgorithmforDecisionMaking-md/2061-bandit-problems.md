---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Bandit Problems
---

# Bandit Problems

_Source page: 321_



These bandit problems were ex-


plored during World War II and


Early analyses of the exploration-exploitation trade-off were focused on slot


proved exceptionally challenging


machines, also called


one-armed bandits


The name comes from older slot machines


to solve. According to Peter Whit-


tle, ‘‘efforts to solve [bandit prob-


having a single pull lever, as well as the fact that the machine tends to take the


lems] so sapped the energies and


gambler’s money. Many real-world problems can be framed as


multiarmed bandit


minds of Allied analysts that the


suggestion was made that the prob-


problems


such as the allocation of clinical trials and adaptive network routing.


lem be dropped over Germany as


Many bandit problem formulations exist in the literature, but this chapter will


the ultimate instrument of intellec-


focus on what is called a


binary bandit


Bernoulli bandit


, or


binomial bandit


. In these


tual sabotage.’’ J. C. Gittins, “Ban-


dit Processes and Dynamic Allo-


problems, arm


pays off


with probability


, and


otherwise. Pulling an arm


cation Indices,”


Journal of the Royal


costs nothing, but we have only


pulls.


Statistical Society. Series B (Method-


ological)


, vol. 41, no. 2, pp. 148–177,


A bandit problem can be framed as an


-step MDP with a single state,


actions,


1979.


and an unknown, stochastic reward function


, as shown in figure 15.1.


C. Szepesvári and T. Lattimore,


Recall that


is the expected reward when taking action


in


, but individual


Bandit Algorithms


. Cambridge Uni-


versity Press, 2020.


rewards realized in the environment may come from a probability distribution.


300


chapter 15. exploration and exploitation


reward with probability


pull arm


reward with probability


pull arm


reward with probability


pull arm


Figure 15.1. The multiarmed ban-


reward with probability


dit problem is a single-state MDP


where actions can differ only in


the likelihood that they produce


reward.


reward with probability


pull arm


reward with probability


Algorithm 15.1 defines the simulation loop for a bandit problem. At each step,


we evaluate our exploration policy


on our current model of the payoff probabil-


ities to generate an action


. The next section will discuss a way to model payoff


probabilities, and the remainder of the chapter will outline several exploration


strategies. After obtaining


, we simulate a pull of that arm, returning binary


reward


. The model is then updated using the observed


and


. The simulation


loop is repeated to horizon


Algorithm 15.1.


Simulation of a


struct


BanditProblem


bandit problem. A bandit problem


# vector of payoff probabilities


is defined by a vector


of payoff


# reward sampler


probabilities, one per action. We


end


also define a function


that simu-


lates the generation of a stochastic


function


BanditProblem


rand


()


binary reward in response to the se-


return


BanditProblem


lection of an action. Each step of a


end


simulation involves generating an


action


from the exploration pol-


function


simulate


::


BanditProblem


model


icy


. The exploration policy gener-


for


in 1


ally consults the model in the selec-


model


tion of the action. The selection of


that action results in a randomly


update!


model


generated reward, which is then


end


used to update the model. Simu-


end


lations are run to horizon


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


15.2. bayesian model estimation


301