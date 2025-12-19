---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Point-Based Value Iteration
---

# Point-Based Value Iteration

_Source page: 453_



QMDP and the fast informed bound generate one alpha vector for each action,


but the optimal value function is often better approximated by many more


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


432


chapter 21. offline belief state planning


Algorithm 21.5. Implementation of


function


blind_lowerbound


k_max


the blind lower bound represented


as a set of alpha vectors.


sum


s′


for


s′


in


enumerate


))


baws_lowerbound


for


in


for


in 1


k_max


[[


for


in


for


in


zip


)]


end


return


end


A survey of point-based value it-


alpha vectors.


Point-based value iteration


computes


different alpha vectors


eration methods are provided by