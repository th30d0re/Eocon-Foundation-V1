---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Mountain Car
---

# Mountain Car

_Source page: 634_



Based Learning for Robot Control,”


Ph.D. dissertation, University of


Cambridge, 1990. Its popular, sim-


In the


mountain car problem


a vehicle must drive to the right, out of a valley.


pler form, with a discrete action


The valley walls are steep enough that blindly accelerating toward the goal with


space, was first given in S. P. Singh


and R. S. Sutton, “Reinforcement


insufficient speed causes the vehicle to come to a halt and slide back down. The


Learning with Replacing Eligibility


agent must learn to accelerate left first in order to gain enough momentum on


Traces,”


Machine Learning


, vol. 22,


the return to make it up the hill.


pp. 123–158, 1996.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


f.5. simple regulator


613


The state is the vehicle’s horizontal position