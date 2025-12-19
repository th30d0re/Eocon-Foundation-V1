---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 455_



ing up a belief for a POMDP with


discrete state and action spaces,


where


is a vector of alpha vectors


Γa


[]


and


is a belief vector at which


for


in


to apply the backup. The


update


Γao


[]


method for vector beliefs is defined


for


in


b′


update


in algorithm 19.2.


push!


Γao


argmax


->


α⋅b′


))


end


sum


sum


s′


s′


Γao


][


for


s′


in


enumerate


))


for


in


enumerate


))


for


in


push!


Γa


end


return


argmax


->


α⋅b


Γa


end