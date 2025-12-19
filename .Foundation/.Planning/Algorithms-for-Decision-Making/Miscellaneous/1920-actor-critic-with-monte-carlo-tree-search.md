---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Actor-Critic with Monte Carlo Tree Search
---

# Actor-Critic with Monte Carlo Tree Search

_Source page: 296_



We can extend concepts from online planning (chapter 9) to the actor-critic setting


Deterministic


policy


gradient


in which we improve a parameterized policy


and a parameterized value


used


, but this approach uses


function


This section discusses the application of Monte Carlo tree search


like the other actor-critic


(section 9.6) to learning a stochastic policy with a discrete action space. We use


methods discussed in this chapter.


our parameterized policy and value function to guide Monte Carlo tree search,


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


13.4. actor-critic with monte carlo tree search


275


Example 13.2. An application of


Consider applying the deterministic policy gradient algorithm to the simple


the deterministic policy gradient


regulator problem. Suppose we use a simple parameterized deterministic


method to the simple regulator


problem and an exploration of the


policy