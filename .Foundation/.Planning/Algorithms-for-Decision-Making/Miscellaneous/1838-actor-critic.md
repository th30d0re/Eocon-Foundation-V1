---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Actor-Critic
---

# Actor-Critic

_Source page: 289_



In actor-critic methods, we have an actor represented by a policy


, param-


eterized by


with the help of a critic that provides an estimate of the value


function


, or


parameterized by


. We will start this


chapter with a simple actor-critic approach in which the optimization of


is


done through gradient ascent, with the gradient of our objective being the same


as in equation (11.44):


#