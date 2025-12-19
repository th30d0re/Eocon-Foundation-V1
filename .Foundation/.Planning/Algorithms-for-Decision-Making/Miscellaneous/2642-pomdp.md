---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 435_



::


Vector


findmax


->


lookahead


),


return


end


struct


LookaheadAlphaVectorPolicy


# POMDP problem


# alpha vectors


end


function


utility


::


LookaheadAlphaVectorPolicy


return


maximum


α⋅b


for


in


end


function


greedy


utility


return


greedy


end


::


LookaheadAlphaVectorPolicy


)(


greedy


).


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


414


chapter 20. exact belief state planning


Example 20.2. Applying a looka-


Consider using one-step lookahead on the crying baby problem with a value


head policy to the crying baby


function given by the alpha vectors