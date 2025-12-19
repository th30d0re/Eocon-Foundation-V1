---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Linear Program Formulation
---

# Linear Program Formulation

_Source page: 169_



The problem of finding an optimal policy can be formulated as a


linear program


which is an optimization problem with a linear objective function and a set of


linear equality or inequality constraints. Once a problem is represented as a linear


15


15


For an overview of linear pro-


program, we can use one of many linear programming solvers.


gramming, see R. Vanderbei,


Lin-


To show how we can convert the Bellman optimality equation into a linear


ear Programming, Foundations and


program, we begin by replacing the equality in the Bellman optimality equation


Extensions


, 4th ed. Springer, 2014.


16


16


Intuitively, we want to push the


with a set of inequality constraints while minimizing


at each state


value


at all states


down in


order to convert the inequality con-


minimize


straints into equality constraints.


Hence, we minimize the sum of all