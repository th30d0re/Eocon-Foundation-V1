---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 444_



Exercise 20.1.


Can every POMDP be framed as an MDP?


Solution:


Yes. Any POMDP can equivalently be viewed as a belief-state MDP whose state


space is the space of beliefs in the POMDP, whose action space is the same as that of the


POMDP and whose transition function is given by equation (20.2).


Exercise 20.2.


What are the alpha vectors for the one-step crying baby problem (ap-


pendix F.7)? Are all the available actions dominant?


Solution:


There are three one-step conditional plans, one for each action, resulting in three


alpha vectors. The optimal one-step policy must choose between these actions, given the


current belief. The one-step alpha vectors for a POMDP can be obtained from the optimal


one-step belief value function:


) =


max


Feeding the baby yields an expected reward:


hungry


feed


hungry


) +


sated


feed


sated


15


hungry


hungry


))


10


hungry


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


20.8. exercises


423


Singing to the baby yields an expected reward:


hungry


sing


hungry


) +


sated


sing


sated