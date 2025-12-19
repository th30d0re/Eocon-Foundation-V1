---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Maximum Margin Inverse Reinforcement Learning
---

# Maximum Margin Inverse Reinforcement Learning

_Source page: 383_



make up the difference in what has


not already been learned.


In many application settings, we have no expert that can be interactively queried;


but instead we have a batch of expert demonstration trajectories. We will assume


that the expert demonstration data


consists of


trajectories. Each trajectory


in


involves a rollout to depth


. In


inverse reinforcement learning


, we assume that


the expert is optimizing an unknown reward function. From


, we attempt to


derive that reward function. With that reward function, we can use the methods


discussed in prior chapters to derive an optimal policy.


There are different approaches to inverse reinforcement learning. We generally


need to define a parameterization of the reward function. A common assumption


is that this parameterization is linear, with