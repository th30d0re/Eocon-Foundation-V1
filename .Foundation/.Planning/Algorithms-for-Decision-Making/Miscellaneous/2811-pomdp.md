---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 462_



randomly sampling the next belief


rand


SetCategorical


))


b′


and reward


, given the current


s′


TRO


belief


and action


in problem


b′


update


return


b′


end


We can create


from the belief states reachable from some initial belief under


a random policy. This


random belief expansion


procedure (algorithm 21.12) may


explore much more of the belief space than might be necessary; the belief space


reachable by a random policy can be much larger than the space reachable by


an optimal policy. Of course, computing the belief space that is reachable by an


optimal policy generally requires knowing the optimal policy, which is what


we want to compute in the first place. One approach that can be taken is to use


This is the intuition behind the


successive approximations of the optimal policy to iteratively generate


algorithm known as


Successive Ap-


In addition to wanting our belief points to be focused on the reachable belief


proximations of the Reachable Space


space, we want those points to be spread out to allow better value function


under Optimal Policies