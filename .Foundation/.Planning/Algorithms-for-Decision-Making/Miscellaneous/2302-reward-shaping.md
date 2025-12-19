---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Reward Shaping
---

# Reward Shaping

_Source page: 365_



Reward function augmentation can also improve learning, especially in problems


with sparse rewards. For example, if we are trying to reach a single goal state, we


could supplement the reward function by an amount that is inversely proportional


to the distance to the goal. Alternatively, we could add another penalty based


on how far we are from the goal. If we are playing chess, for instance, we might


add a penalty to our reward function when we lose a piece, even though we only


care about winning or losing the game at the end, not about winning or losing


individual pieces.


Modifying the reward function during training by incorporating domain knowl-


edge to speed training is known as


reward shaping


. Suppose that rewards in our


problem are generated according to


, allowing rewards to depend on


the resulting state. We will use


to represent our


shaping function


. During


training, instead of using


as our reward, we use