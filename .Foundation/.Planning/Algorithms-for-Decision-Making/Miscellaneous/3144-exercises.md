---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 508_



Exercise 23.1.


List any advantages that a controller policy representation has over tree-


based conditional plan and belief-based representations.


Solution:


Unlike tree-based conditional plans, controllers can represent policies that can be


executed indefinitely. They do not have to grow exponentially in size with the horizon.


Compared to belief-based representations, the number of parameters in a controller


representation tends to be far less than the number of alpha vectors for larger problems.


We can also optimize controllers more easily for a fixed amount of memory.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


23.6. exercises


487


Algorithm 23.6. An implementa-


struct


ControllerGradient


tion of a controller gradient ascent


# initial belief


algorithm for POMDP


at initial


# number of nodes


belief


. The controller itself has a


# gradient step


fixed size of


nodes. It is improved


k_max


# maximum iterations


over


k_max


iterations by following


end


the gradient of the controller, with


function


solve


::


ControllerGradient


::