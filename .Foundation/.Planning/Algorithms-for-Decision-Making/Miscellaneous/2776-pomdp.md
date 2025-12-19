---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 457_



::


RandomizedPointBasedValueIteration


Γ′


B′


[],


copy


a vector of beliefs and


k_max


is the


while


isempty


B′


number of iterations.


rand


B′


argmax


->


α⋅b


α′


backup


if


α′⋅b


α⋅b


push!


Γ′


α′


else


push!


Γ′


end


filter!


->


maximum


α⋅b


for


in


Γ′


maximum


α⋅b


for


in


),


B′


end


return


Γ′


end


function


solve


::


RandomizedPointBasedValueIteration


baws_lowerbound


)]


alphavector_iteration


return


LookaheadAlphaVectorPolicy


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


436


chapter 21. offline belief state planning


Figure 21.5.


Approximate value


iterations


functions obtained using random-


iterations


ized point-based value iteration


10


iterations


on the crying baby problem with


belief points at