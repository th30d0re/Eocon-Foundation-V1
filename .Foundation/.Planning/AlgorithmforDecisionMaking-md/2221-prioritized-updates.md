---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Prioritized Updates
---

# Prioritized Updates

_Source page: 343_



A. W. Moore and C. G. Atkeson,


An approach called


prioritized sweeping


(algorithm 16.5) uses a priority queue to


“Prioritized Sweeping: Reinforce-


help identify which states are most in need of updating. A transition from


to


is


ment Learning with Less Data


followed by an update of


based on our updated transition and reward models.


and Less Time,”


Machine Learning


vol. 13, no. 1, pp. 103–130, 1993.


We then iterate over all state-action pairs


that can immediately transition


into


. The priority of any such


is increased to