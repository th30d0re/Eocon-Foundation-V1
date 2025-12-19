---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Softmax Response
---

# Softmax Response

_Source page: 542_



Similar to what was done in the previous chapter, we can define a


softmax response


policy


, which assigns a stochastic response to the policies of the other agents at


each state. As we did in the construction of a deterministic best response policy,


we solve an MDP where the agents with the fixed policies


are folded into the


environment. We then extract the action value function


using one-step


lookahead. The softmax response is


exp