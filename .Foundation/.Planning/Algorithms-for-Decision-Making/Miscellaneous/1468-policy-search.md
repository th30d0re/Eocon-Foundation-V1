---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Policy Search
---

# Policy Search

_Source page: 235_



Policy search


involves searching the space of policies without directly computing a


value function. The policy space is often lower-dimensional than the state space


and can often be searched more efficiently. Policy optimization optimizes the


parameters in a


parameterized policy


in order to maximize utility. This parameter-


ized policy can take many forms, such as neural networks, decision trees, and


computer programs. This chapter begins by discussing a way to estimate the value


of a policy given an initial state distribution. We will then discuss search methods


that do not use estimates of the gradient of the policy, saving gradient methods


for the next chapter. Although local search can be quite effective in practice, we


will also discuss a few alternative optimization approaches that can avoid local


There are many other optimiza-


optima.


tion


approaches,


as


discussed


by


M. J.


Kochenderfer


and


T. A.


Wheeler,


Algorithms


for