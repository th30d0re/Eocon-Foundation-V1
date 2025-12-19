---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Receding Horizon Planning
---

# Receding Horizon Planning

_Source page: 203_



In


receding horizon planning


, we plan from the current state to a maximum fixed


horizon or depth


. We then execute the action from our current state, transition to


the next state, and replan. The online planning methods discussed in this chapter


follow this receding horizon planning scheme. They differ in how they explore


different courses of action.


A challenge in applying receding horizon planning is determining the appro-


priate depth. Deeper planning generally requires more computation. For some


problems, a shallow depth can be quite effective; the fact that we replan at each


step can compensate for our lack of longer-term modeling. In other problems,


greater planning depths may be necessary so that our planner can be driven


toward goals or away from unsafe states, as illustrated in example 9.1.


182


chapter 9. online planning


Example 9.1.


Receding horizon


Suppose we want to apply receding horizon planning to aircraft collision


planning for collision avoidance to


avoidance. The objective is to provide descend or climb advisories when


different planning depths. In this


problem, there are four state vari-


necessary to avoid collision. A collision occurs when our altitude relative


ables. These plots show slices of the


to the intruder


is within


50 m


and the time to potential collision


col


is


state space under the assumption


zero. We want to plan deeply enough so that we can provide an advisory


that the aircraft is currently level


and there has not yet been an ad-


sufficiently early to avoid collision with a high degree of confidence. The plots


visory. The horizontal axis is the


here show the actions that would be taken by a receding horizon planner


time to collision


, and the ver-


col


tical axis is our altitude


relative


with different depths.


to the intruder. Appendix F.6 pro-


vides additional details about this


problem.


Horizon 10


Horizon 20


Horizon 40


200


climb


descend


100


100


200


20


30


20


30


20


30


10


40


10


40


10


40


col


col


col


If the depth is


10


, we provide advisories only within


10 s


of collision. Due


to the limitations of the vehicle dynamics and the uncertainty of the behavior


of the other aircraft, providing advisories this late compromises safety. With


20


, we can do better, but there are cases where we would want to alert a


little earlier to further reduce collision risk. There is no motivation to plan


deeper than


40


because we do not need to advise any maneuvers that


far ahead of potential collision.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


9.2. lookahead with rollouts


183