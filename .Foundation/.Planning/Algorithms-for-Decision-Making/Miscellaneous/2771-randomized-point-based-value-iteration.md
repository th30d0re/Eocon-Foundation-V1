---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Randomized Point-Based Value Iteration
---

# Randomized Point-Based Value Iteration

_Source page: 455_



Randomized point-based value iteration


(algorithm 21.8) is a variation of the point-


M. T. J. Spaan and N. A. Vlassis,


based value iteration approach from the previous section.


The primary difference


“Perseus: Randomized Point-Based


is the fact that we are not forced to maintain an alpha vector at every belief in


Value Iteration for POMDPs,”


Jour-


We initialize the algorithm with a single alpha vector in


, and then update


at


nal of Artificial Intelligence Research


vol. 24, pp. 195–220, 2005.


every iteration, potentially increasing or decreasing the number of alpha vectors


in


as appropriate. This modification of the update step can improve efficiency.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


434


chapter 21. offline belief state planning


Algorithm 21.7. Point-based value


struct


PointBasedValueIteration


iteration, which finds an approx-


# set of belief points


imately optimal policy for an


k_max


# maximum number of iterations


infinite-horizon POMDP with dis-


end


crete state, action, and observation


spaces, where


is a vector of be-


function


update


::