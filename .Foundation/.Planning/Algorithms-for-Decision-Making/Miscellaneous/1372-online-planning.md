---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Online Planning
---

# Online Planning

_Source page: 203_



The solution methods we have discussed so far compute policies offline, before


any actions are executed in the real problem. Even offline approximation methods


can be intractable in many high-dimensional problems. This chapter discusses


online planning


methods that find actions based on reasoning about states that


are reachable from the current state. The


reachable state space


is often orders of


magnitude smaller than the full state space, which can significantly reduce storage


and computational requirements compared to offline methods. We will discuss


a variety of algorithms that aim to make online planning efficient, including


pruning the state space, sampling, and planning more deeply along trajectories


that appear more promising.