---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Lookahead with Rollouts
---

# Lookahead with Rollouts

_Source page: 475_



...


...


...


Algorithm 9.1 introduced lookahead with rollouts as an online method in fully


...


...


observed problems. The algorithm can be used directly for partially observed


...


problems. It uses a function for randomly sampling the next state, which corre-


...


...


sponds to a belief state in the context of partial observability. This function was


...


already introduced in algorithm 21.11. Because we can use a generative model


...


...


rather than an explicit model for transitions, rewards, and observations, we can


...


accommodate problems with high-dimensional state and observation spaces.


...


...


...