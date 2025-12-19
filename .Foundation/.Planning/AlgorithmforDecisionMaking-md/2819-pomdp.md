---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 465_



πfib


solve


FastInformedBound


k_fib


),


Vhi


Dict


=>


utility


πfib


for


in


basis


))


πhi


SawtoothPolicy


Vhi


πlo


LookaheadAlphaVectorPolicy


, [


baws_lowerbound


)])


for


in 1


k_max


explore!


πhi


πlo


if


utility


πhi


utility


πlo


break


end


end


return


πlo


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


444


chapter 21. offline belief state planning


At each iteration, we explore beliefs that are reachable from our initial belief


to a maximum depth. As we explore, we update the set of belief-action pairs


forming our sawtooth upper bound and the set of alpha vectors forming our


lower bound. We stop exploring after a certain number of iterations or until the


gap at our initial state is below a threshold


When we encounter a belief


along our path from the initial node during our


exploration, we check whether the gap at


is below a threshold


, where


is our current depth. If we are below that threshold, then we can stop exploring


along that branch. We want the threshold to increase as


increases because the


gap at


after an update is at most


times the weighted average of the gap at the


beliefs that are immediately reachable.


If the gap at


is above the threshold and we have not reached our maximum


depth, then we can explore the next belief,


. First, we determine the action


recommended by our sawtooth policy. Then, we choose the observation


that


12


12


Some variants simply sample the


maximizes the gap at the resulting belief.


We recursively explore down the tree.


next observations. Others select


After exploring the descendants of


, we add


to


, where


is the one-step


the observation that maximizes the


lookahead value of


. We add to


the alpha vector that results from a backup at


gap weighted by its likelihood.


. Figure 21.8 shows the tightening of the bounds.


Figure 21.8. The evolution of the


iteration


iteration


iteration


upper bound, represented by saw-


tooth pairs, and the lower bound,


represented by alpha vectors for


10


10


10


the crying baby problem. The op-


timal value function is shown in


20


20


20


black.


30


30


30


0.2


0.6


0.8


0.2


0.6


0.8


0.2


0.6


0.8


0.4


0.4


0.4


iteration


iteration


iteration


10


10


10


20


20


20


30


30


30


0.2


0.6


0.8


0.2


0.6


0.8


0.2


0.6


0.8


0.4


0.4


0.4


hungry


hungry


hungry


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


21.9. triangulated value functions


445