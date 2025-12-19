---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Collaborative Predator-Prey Hex World
---

# Collaborative Predator-Prey Hex World

_Source page: 647_



The


collaborative predator-prey hex world


is a variant of the predator-prey hex world


in which a team of predators chase a single, moving prey. The predators must


work together to capture a prey. The prey moves randomly to a neighboring cell


that is not occupied by a predator.


Predators also only make noisy local observations of the environment. Each


predator


detects whether a prey is within a neighboring cell


prey


nothing


The predators are penalized with a


reward for movement. They receive a re-


ward of


10


if one or more of them capture the prey, meaning that they are in the


same cell as the prey. At this point, the prey is randomly assigned a new cell,


signifying the arrival of a new prey for the predators to begin hunting again.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com