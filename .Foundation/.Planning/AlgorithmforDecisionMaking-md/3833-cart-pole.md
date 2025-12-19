---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Cart-Pole
---

# Cart-Pole

_Source page: 633_



A. G. Barto, R. S. Sutton, and C. W.


The


cart-pole problem


also sometimes called the


pole balancing problem


, has the


Anderson, “Neuronlike Adaptive


agent move a cart back and forth. As shown in figure F.6, this cart has a rigid pole


Elements That Can Solve Diffi-


attached to it by a swivel, so that as the cart moves back and forth, the pole begins


cult Learning Control Problems,”


IEEE Transactions on Systems, Man,


to rotate. The objective is to keep the pole vertically balanced while keeping the


and Cybernetics


, vol. SMC-13, no. 5,


cart within the allowed lateral bounds. As such,


reward is obtained each time


pp. 834–846, 1983.


step in which these conditions are met, and transition to a terminal zero-reward


state occurs whenever they are not.


The actions are to either apply a left or right force


to the cart. The state


space is defined by four continuous variables: the lateral position of the cart


, its


lateral velocity


, the angle of the pole


, and the pole’s angular velocity


. The


We use the parameters imple-


problem involves a variety of parameters, including the mass of the cart


, the


mented in the OpenAI Gym. G.


cart


Brockman, V. Cheung, L. Petters-


mass of the pole


, the pole length


, the force magnitude


, gravitational


pole


son, J. Schneider, J. Schulman, J.


acceleration


, the time step


, the maximum


deviation, the maximum angular


Tang, and W. Zaremba, “OpenAI


Gym,” 2016. arXiv: 1606.01540v1.


deviation, and friction losses between the cart and the pole or between the cart


and its track.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


612


appendix f. problems


Figure F.6. In the cart-pole prob-


lem, a vehicle must alternate be-


tween accelerating left and right in


order to balance a pole. The pole


is not allowed to fall past a given


gravity


angle, and the cart is not allowed


to travel outside of given limits.


Given an input force


, the angular acceleration of the pole is


sin


cos