---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 578_



Exercise 27.1.


Why is a Dec-MDP with joint full observability different from agents


knowing the state?


Solution:


Full joint observability means if agents were to share their individual observations,


then the team would know the true state. This can be done offline during planning. Thus


in Dec-MDPs, the true state is essentially known during planning. The issue is that it


requires agents to share their individual observations, which cannot be done online during


execution. Therefore, planning still needs to reason about the uncertain observations made


by the other agents.


Exercise 27.2.


Propose a fast algorithm for a Dec-MDP with transition, observation, and


reward independence. Prove that it is correct.


Solution:


If a factored Dec-MDP satisfies all three independence assumptions, then we can


solve it as


|I|


separate MDPs. The resulting policy


for each agent


’s MDP can then be


combined to form the optimal joint policy. To prove this fact, consider the utility of each


agent’s individual MDP:


) =


()


()


()


As in equation (26.1),


()


refers to the root action of


’s conditional plan, and


refers to


’s subplans after making observation


. We sum up each of their individual


contributions as follows:


##


) =


()


()


()


We can combine


and


into a single probability distribution


, move the summation,


and apply the definition of reward independence:


##


) =


()


()


()


##


()


()


()


##