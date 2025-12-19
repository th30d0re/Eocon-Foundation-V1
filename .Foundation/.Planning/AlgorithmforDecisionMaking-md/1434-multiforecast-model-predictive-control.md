---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Multiforecast Model Predictive Control
---

# Multiforecast Model Predictive Control

_Source page: 229_



14


S. Garatti and M. C. Campi,


One way to address the computational challenge within the minimax problem


“Modulating Robustness in Con-


in equation (9.5) is to use


forecast scenarios, each of which follows its own


trol Design: Principles and Algo-


14


deterministic transition function.


There are various formulations of this kind of


rithms,”


IEEE Control Systems Mag-


15


azine


, vol. 33, no. 2, pp. 36–51, 2013.


multiforecast model predictive control


, which is a type of


hindsight optimization


One


15


It is called hindsight optimiza-


common approach is to have the deterministic transition functions depend on


tion because it represents a solu-


the step


, which is the same as augmenting the state space to include


tion that is optimizing using knowl-


edge about action outcomes that


depth. Example 9.11 demonstrates how this might be done for a linear Gaussian


can only be known in hindsight.


model.


E. K. P. Chong, R. L. Givan, and


H. S. Chang, “A Framework for


Simulation-Based Network Con-


Suppose we have a problem with linear Gaussian dynamics:


trol via Hindsight Optimization,”


in


IEEE Conference on Decision and