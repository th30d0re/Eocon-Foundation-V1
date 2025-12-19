---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 399_



). A common approach to solving POMDPs involves inferring a belief


distribution over the underlying state at the current time step and then applying


a policy that maps beliefs to actions. We will show how to update our belief


distribution, given a past sequence of observations and actions. This enables


us to devise exact solution methods for optimizing these belief-based policies.


Unfortunately, POMDPs are intractable to optimally solve for all but the smallest


of problems. We review a variety of offline approximation methods that tend


to scale much better than exact methods to larger problems. We also show how


to extend some of the online approximations discussed earlier in this book to


accommodate partial observability. Finally, we introduce finite state controllers


as an alternative policy representation and discuss methods that optimize them


to solve POMDPs.