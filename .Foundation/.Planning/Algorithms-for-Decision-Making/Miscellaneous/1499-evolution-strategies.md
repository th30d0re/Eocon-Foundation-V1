---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Evolution Strategies
---

# Evolution Strategies

_Source page: 241_



D. Wierstra, T. Schaul, T. Glas-


Evolution strategies


update a search distribution parameterized by a vector


at


machers, Y. Sun, J. Peters, and


each iteration. However, instead of fitting the distribution to a set of elite samples,


J. Schmidhuber, “Natural Evolu-


10


they update the distribution by taking a step in the direction of the gradient.


tion Strategies,”


Journal of Machine


11


Learning Research


, vol. 15, pp. 949–


The gradient of the objective in equation (10.5) can be computed as follows:


980, 2014.


10


We are effectively doing gradi-


ent ascent, which is reviewed in ap-


pendix A.11.


11


The policy parameter


is not


bolded here because it is not re-


quired to be a vector. However,


is in bold because we require it to


be a vector when we work with the


gradient of the objective.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


220


chapter 10. policy search


Algorithm 10.4. Cross entropy pol-


struct


CrossEntropyPolicySearch


icy search, which iteratively im-


# initial distribution


proves a search distribution ini-


# number of samples


tially set to


. This algorithm takes


m_elite


# number of elite samples


as input a parameterized policy


k_max


# number of iterations


and a policy evaluation


end


function


. In each iteration,


function


optimize_dist


::


CrossEntropyPolicySearch


samples are drawn and the top


m_elite


k_max


m_elite


k_max


m_elite


are used to refit the dis-


for


in 1


k_max


tribution. The algorithm termi-


θs


rand


nates after


k_max


iterations. The


us


θs


])


for


in 1


distribution


can be defined us-


θ_elite


θs


sortperm


us


)[(


m_elite


]]


ing the


Distributions.jl


pack-


Distributions


fit


typeof


),


θ_elite


age. For example, we might define


end


0.0


1.0


return