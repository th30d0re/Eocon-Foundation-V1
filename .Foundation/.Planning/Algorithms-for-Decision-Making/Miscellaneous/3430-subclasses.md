---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Subclasses
---

# Subclasses

_Source page: 568_



There are many notable subclasses of Dec-POMDPs. Categorizing these subclasses


is useful when designing algorithms that take advantage of their specific structure.


One attribute of interest is


joint full observability


, which is when each agent


observes an aspect of the state, such that if they were to combine their observations,


it would uniquely reveal the true state. The agents, however, do not share their


observations. This property ensures that if


then