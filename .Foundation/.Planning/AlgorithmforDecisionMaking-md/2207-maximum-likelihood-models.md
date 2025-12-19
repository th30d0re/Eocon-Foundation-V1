---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Maximum Likelihood Models
---

# Maximum Likelihood Models

_Source page: 339_



As introduced in section 15.6 and implemented in algorithm 15.9, reinforcement


learning involves using information about past state transitions and rewards


to inform decisions. This section describes how to obtain a


maximum likelihood


estimate


of the underlying problem. This maximum likelihood estimate can be


used to generate a value function estimate that can be used with an exploration


strategy to generate actions.


We record the transition counts


, indicating the number of times a


transition from


to


was observed when taking action


. The maximum likeli-


hood estimate of the transition function given these transition counts is