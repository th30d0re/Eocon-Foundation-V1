---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 394_



Exercise 18.1.


Consider applying behavioral cloning to a discrete problem where we have


been given expert demonstrations. We could define a feature function


and represent


the policy with a softmax distribution:


exp


))


We would then learn the parameters


for each action from the expert data. Why might


we want to use this approach over one where we directly estimate a discrete distribution


for each state, with one parameter per state-action pair?


Solution:


In imitation learning, we are generally limited to a relatively small set of expert


demonstrations. The distribution


has