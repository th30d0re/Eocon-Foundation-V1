---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Open-Loop Planning
---

# Open-Loop Planning

_Source page: 222_



The online methods discussed in this chapter, as well as the offline methods


discussed in the previous chapters, are examples of


closed-loop planning


, which


10


10


The loop in this context refers to


involves accounting for future state information in the planning process.


Often,


the observe-act loop introduced in


open-loop planning


can provide a satisfactory approximation of an optimal closed-


section 1.1.


loop plan while greatly enhancing computational efficiency by avoiding having


to reason about the acquisition of future information. Sometimes this open-loop


11


11


F. Borrelli, A. Bemporad, and M.


planning approach is referred to as


model predictive control


As with receding


Morari,


Predictive Control for Lin-


horizon control, model predictive control solves the open-loop problem, executes


ear and Hybrid Systems


. Cambridge


the action from our current state, transitions to the next state, and then replans.


University Press, 2019.


Open-loop plans can be represented as a sequence of actions up to a depth


The planning process reduces to an optimization problem:


maximize