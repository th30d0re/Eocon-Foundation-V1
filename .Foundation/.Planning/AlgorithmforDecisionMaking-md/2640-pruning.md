---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Pruning
---

# Pruning

_Source page: 434_



If we have a collection of alpha vectors


, we may want to


prune


alpha vectors


that do not contribute to our representation of the value function or plans that


are not optimal for any belief. Removing such alpha vectors or plans can improve


computational efficiency. We can check whether an alpha vector


is


dominated


by


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


20.4. pruning


413


Algorithm 20.5.


A policy repre-


function


lookahead


::