---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 57_



. Given


, in-


formation about


provides no additional information about


, and vice versa.


Example 2.6 shows an instance of this.


Example 2.6. Conditional indepen-


Suppose the presence of satellite trajectory deviation (


) is conditionally


dence in the satellite-tracking prob-


independent of whether we have a communication loss (


) given knowledge


lem.


of whether we have an electrical system failure (


). We would write this


. If we know that we have an electrical system failure, then the


fact that we observe a loss of communication has no impact on our belief


that there is a trajectory deviation. We may have an elevated expectation


that there is a trajectory deviation, but that is only because we know that an


electrical system failure has occurred.


We can use a set of rules to determine whether the structure of a Bayesian


network implies that two variables must be conditionally independent given a set


19


19


Even if the structure of a network


of other evidence variables.


Suppose that we want to check whether