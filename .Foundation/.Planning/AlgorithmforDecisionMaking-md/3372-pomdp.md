---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 556_



model


attempts


to


joint observations are not observed. Inferring a probability distribution over joint


capture this infinite regression.


actions requires that each agent reason about the other agents reasoning about


P. J. Gmytrasiewicz and P. Doshi,


“A


Framework


for


Sequential


each other, who are in turn reasoning about each other, and so on. Inferring


Planning in Multi-Agent Settings,”


a distribution over the other observations is just as complicated because the


Journal


of


Artificial


Intelligence


observations depend on the actions of the other agents.


Research


, vol. 24, no. 1, pp. 49–79,


2005. While this is a compu-


Because of the difficulty of explicitly modeling beliefs in POMGs, we will focus


tationally


complex


framework


on policy representations that do not require a belief to determine an action.


because it reasons in both time and


depth, algorithms for such models


We can use the tree-based conditional plan representation and the graph-based


have


advanced


tremendously


controller representation introduced in the earlier chapters on POMDPs. As in


toward the goal of pragmatic


use cases. E. Sonu, Y. Chen, and


MGs, each agent in a POMG acts according to a policy


, or equivalently, the


P.


Doshi,


“Decision-Theoretic


agents act together according to a joint policy