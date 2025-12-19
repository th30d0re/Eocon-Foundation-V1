---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Kernel Smoothing
---

# Kernel Smoothing

_Source page: 186_



Another local approximation method is


kernel smoothing


, where the utilities of


the states in


are smoothed over the entire state space. This method requires


defining a


kernel function


that relates pairs of states


and


. We generally


want


to be higher for states that are closer together because those values


tell us how to weight together the utilities associated with the states in


. This


method results in the following linear approximation: