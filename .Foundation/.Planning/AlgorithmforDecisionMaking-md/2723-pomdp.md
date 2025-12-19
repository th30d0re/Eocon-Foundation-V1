---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 449_



for updating a set of alpha vec-


for


in 1


k_max


tors


used by several of the meth-


update


ods in this chapter. The various


end


methods, including QMDP, differ


return


in their implementation of


update


end


After


k_max


iterations, this function


returns a policy represented by the


alpha vectors in


428


chapter 21. offline belief state planning


QMDP (algorithm 21.2) constructs a single alpha vector


for each action


using value iteration. Each alpha vector is initialized to zero, and then we iterate: