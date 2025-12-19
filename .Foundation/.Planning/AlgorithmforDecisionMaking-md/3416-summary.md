---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 564_



POMGs generalize POMDPs to multiple agents and MGs to partial observabil-


ity.


Because agents generally cannot maintain beliefs in POMGs, policies typically


take the form of conditional plans or finite state controllers.


Nash equilibria, in the form of


-step conditional plans for POMGs, can be


obtained by finding Nash equilibria for simple games whose joint actions


consist of all possible POMG joint policies.


Dynamic programming approaches can be used to compute Nash equilibria


more efficiently by iteratively constructing sets of deeper conditional plans


while pruning dominated plans to restrict the search space.