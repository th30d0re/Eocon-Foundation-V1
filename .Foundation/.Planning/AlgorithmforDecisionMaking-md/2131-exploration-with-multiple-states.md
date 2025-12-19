---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exploration with Multiple States
---

# Exploration with Multiple States

_Source page: 331_



10


A survey of algorithms for com-


puting this lookup table are pro-


In the general reinforcement learning context with multiple states, we must use


vided in J. Chakravorty and A. Ma-


hajan, “Multi-Armed Bandits, Git-


observations about state transitions to inform our decisions. We can modify the


tins Index, and Its Calculation,” in


simulation process in algorithm 15.1 to account for state transitions and update


Methods and Applications of Statistics


our model appropriately. Algorithm 15.9 provides an implementation of this.


in Clinical Trials


, N. Balakrishnan,


ed., vol. 2, Wiley, 2014, pp. 416–435.


There are many ways to model the problem and perform exploration, as we will


discuss over the next few chapters, but the simulation structure is exactly the


same.