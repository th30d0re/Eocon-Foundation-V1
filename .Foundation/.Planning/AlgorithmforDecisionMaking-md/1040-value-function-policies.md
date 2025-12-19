---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Value Function Policies
---

# Value Function Policies

_Source page: 161_



The previous section showed how to compute a value function associated with a


policy. This section shows how to extract a policy from a value function, which


we later use when generating optimal policies. Given a value function


, which


may or may not correspond to the optimal value function, we can construct a


policy


that maximizes the lookahead equation introduced in equation (7.5):