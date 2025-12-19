---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Time Complexity Classes
---

# Time Complexity Classes

_Source page: 599_



The difficulty of solving certain problems can be grouped into different time


complexity classes. Important classes that appear frequently throughout this


book include


: problems that can be solved in polynomial time,


NP


: problems whose solutions can be verified in polynomial time,


NP-hard


: problems that are at least as hard as the hardest problems in NP, and


NP-complete


: problems that are both NP-hard and in NP.


The formal definitions of these complexity classes are rather involved. It is


generally believed that


NP


, but it has not been proven and remains one of


NP-hard


the most important open problems in mathematics. In fact, modern cryptography


depends on the fact that there are no known efficient (i.e., polynomial time)


algorithms for solving NP-hard problems. Figure C.1 illustrates the relationships


NP-complete


among the complexity classes, under the assumption that P


NP.


A common approach to proving whether a particular problem


is NP-hard is


NP


to come up with a polynomial transformation from a known


NP-complete


problem


to an instance of


. The