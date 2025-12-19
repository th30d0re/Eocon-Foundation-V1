---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Approximate Value Functions
---

# Approximate Value Functions

_Source page: 183_



A deeper treatment of this topic is


Up to this point, we have assumed that the value function can be represented as a


provided by W. B. Powell,


Approxi-


table. Tables are useful representations only for small, discrete problems. Problems


mate Dynamic Programming: Solving


with larger state spaces may require an infeasible amount of memory, and the


the Curses of Dimensionality


, 2nd ed.


Wiley, 2011. Relevant insights can


exact methods discussed in the previous chapter may require an infeasible amount


be drawn from a variety of fields


of computation. For such problems, we often have to resort to


approximate dynamic


as discussed by W. B. Powell,


Re-


programming


, where the solution may not be exact.


One way to approximate


inforcement Learning and Stochastic


Optimization


. Wiley, 2022.


solutions is to use


value function approximation


, which is the subject of this chapter.


We will discuss different approaches to approximating the value function and how


to incorporate dynamic programming to derive approximately optimal policies.