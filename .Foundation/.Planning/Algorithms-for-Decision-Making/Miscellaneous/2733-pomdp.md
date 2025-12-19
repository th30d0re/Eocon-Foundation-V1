---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 450_



zeros


length


))


for


in


alphavector_iteration


return


AlphaVectorPolicy


end


Figure 21.1.


Value functions ob-


iterations


tained for the crying baby problem


iterations


(appendix F.7) using QMDP. In the


iterations


first iteration, a single alpha vec-


10


tor dominates. In subsequent itera-


iterations


tions, two alpha vectors dominate.


iterations


iterations


20


iterations


iterations


iterations


30


0.2


0.6


0.8


0.4


10


iterations


hungry


100


iterations


optimal value function


When QMDP is run to the horizon in finite horizon problems or to convergence


for infinite-horizon problems, the resulting policy is equivalent to assuming that


there will be full observability after taking the first step. Because we can do better


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


21.2. fast informed bound


429


only if we have full observability, QMDP will produce an upper bound on the


Although the value function rep-


true optimal value function


. In other words,


max


for all


resented by the QMDP alpha vec-


If QMDP is not run to convergence for infinite-horizon problems, it might


tors upper-bounds the optimal


not provide an upper bound. One way to guarantee that QMDP will provide an


value function, the utility realized


by a QMDP policy will not exceed


upper bound after a finite number of iterations is to initialize the value function


that of an optimal policy in expec-


to some upper bound. One rather loose upper bound is the


best-action best-state


tation, of course.


upper bound


, which is the utility obtained from taking the best action from the


best state forever: