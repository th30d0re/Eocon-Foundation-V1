---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Iterated Best Response
---

# Iterated Best Response

_Source page: 572_



Instead of exploring joint policies directly, we can perform a form of


iterated best


response


(algorithm 27.3). In this approach, we iteratively select an agent and


compute a best response policy, assuming that the other agents are following a


This type of algorithm is also


fixed policy.


This approximate algorithm is typically fast because it is choosing


called


joint equilibrium-based search


the best policy for only one agent at a time. Moreover, since all agents share the


for policies