---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 509_



x1


length


),


length


),


length


),


∂U′∂ψ


∂U′∂η


gradient


UIndex


x1


sum


UIndex


x1


)]


for


in 1


ψ′


Dict


((


=>


0.0 for


in


in


η′


Dict


((


x′


=>


0.0 for


in


in


in


x′


in


for


in


ψ′x


∂U′∂ψ


),


x1


for


in


ψ′x


project_to_simplex


ψ′x


for


aIndex


in


enumerate


ψ′


ψ′x


aIndex


end


for


in


product


η′x


[(


x′


∂U′∂η


x′


),


x1


))


for


x′


in


η′x


project_to_simplex


η′x


for


x′Index


x′


in


enumerate


η′


x′


η′x


x′Index


end


end


end


ψ′


η′


end


function


project_to_simplex


sort


copy


),


rev


true


maximum


([


for


in


eachindex


if


sum


]))


0.0


])


sum


for


))


return


max


0.0


for


in


eachindex


)]


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


488


chapter 23. controller abstractions


Algorithm 23.7. The


gradient


step


function


gradient


::


ControllerPolicy


::


ControllerGradient


::