---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: SARSOP
---

# SARSOP

_Source page: 462_



).


H. Kurniawati, D. Hsu, and W. S.


approximation. The quality of the approximation provided by the alpha vectors


Lee, “SARSOP: Efficient Point-


associated with the points in


degrades as we evaluate points farther from


Based POMDP Planning by Ap-


proximating Optimally Reachable


We can take an


exploratory belief expansion


approach (algorithm 21.13), where


Belief Spaces,” in


Robotics: Science


we try every action for every belief in


and add the resulting belief states that


and Systems


, 2008.


are farthest from the beliefs already in the set. Distance in belief space can be


10


The


and


distance between


10


measured in different ways. This algorithm uses the


-norm.


Figure 21.7 shows


is


and is denoted


as


. See appendix A.4.


an example of the belief points added to


using this approach.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


21.7. point selection


441


Algorithm 21.12.


Randomly ex-


function


random_belief_expansion


panding a finite set of beliefs


B′


copy


used in point-based value iteration


for


in


based on reachable beliefs.


rand


b′


randstep


push!


B′


b′


end


return


unique!


B′


end


Algorithm 21.13. Expanding a fi-


function


exploratory_belief_expansion


nite set of beliefs


used in point-


B′


copy


based value iteration by exploring


for


in


the reachable beliefs and adding


best


copy


),


0.0


those that are farthest from the cur-


for


in


rent beliefs.


b′


randstep


minimum


norm


b′


for


in


B′


if


best


best


b′


end


end


push!


B′


best


end


return


unique!


B′


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


442


chapter 21. offline belief state planning


Figure 21.7. Exploratory belief ex-


pansion run on the three-state ma-


chine replacement problem, start-


ing with an initial uniform be-


0.2


lief


= [