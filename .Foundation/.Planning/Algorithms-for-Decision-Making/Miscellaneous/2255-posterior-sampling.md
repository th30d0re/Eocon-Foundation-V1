---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Posterior Sampling
---

# Posterior Sampling

_Source page: 352_



An alternative to solving for the optimal value function over the belief space


M. J. A.


is to use


posterior sampling


which was originally introduced in the context of


Strens,


“A


Bayesian


Framework


for


Reinforcement


exploration in bandit problems in section 15.4.


Here, we draw a sample


from the


Learning,” in


International Confer-


current belief


and then solve for the best action, assuming that


is the true model.


ence on Machine Learning (ICML)


2000.


We then update our belief, draw a new sample, and solve the corresponding MDP.


In that section, we sampled from


Example 16.4 provides an example instance of this.


a posterior distribution over the


An advantage of posterior sampling is that we do not have to decide on heuristic


probability of payoffs and then as-


sumed that the sampled probabili-


exploration parameters. However, solving the MDP at every step can be expensive.


ties were correct when selecting an


A method for sampling a discrete MDP from the posterior is implemented in


action.


algorithm 16.9.


Algorithm


16.9.


The


update


struct


PosteriorSamplingUpdate


end


method for posterior sampling.


After updating the parameters


function


Base


rand


model


::


BayesianMDP


of the Bayesian posterior, we


model


model


sample an MDP problem from that


zeros


length


),


length


),


length


))


posterior.


This


implementation


for


in


for


in


assumes


discrete


state


and


rand


model


])


action


space


with


Dirichlet


end


modeling our uncertainty in the


end


transition probabilities from each


return


MDP


model


model


state-action pair. To generate the


end


transition model, we iterate over


every state and action and sample


function


update!


planner


::


PosteriorSamplingUpdate


model


s′


from


the


associated


Dirichlet


rand


model


distribution. Once we have a


solve


).


sampled problem


, we solve it


copy!


model


using the linear programming


end


formulation and store the resulting


value function


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


16.6. posterior sampling


331


Example 16.4.


Application of


We want to apply Bayesian model estimation to hex world. We start with


Bayesian model estimation and


associating uniform Dirichlet priors with every state-action pair. After


100


posterior sampling to the hex


world problem.


simulations of length


10


and adding our transition counts to our pseudo-


counts in our prior, the parameters of our posterior distributions over our


successor states appear as follows:


We can sample from this distribution to produce the model shown here. No-


tice that it has many more nonzero transition probabilities than the maximum


likelihood models shown in example 16.1.


0.2