---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 504_



x1


collect


tensorform


model


Model


Ipopt


Optimizer


@variable


model


])


@variable


model


@variable


model


@objective


model


Max


b⋅U


x1


])


@NLconstraint


model


, [


],


==


sum


sum


s′


sum


s′


sum


x′


x′


s′


for


x′


in


for


in


for


s′


in


))


for


in


)))


@constraint


model


, [


],


sum


])


==


@constraint


model


, [


],


sum


])


==


optimize!


model


ψ′


η′


value.


),


value.


return


ControllerPolicy


Dict


((


])


=>


ψ′


for


in


in


),


Dict


((


],


],


x′


=>


η′


x′


for


in


in


in


x′


in


))


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


23.4. gradient ascent


483


Example 23.5.


The nonlinear


Here are optimal fixed-size controllers computed using nonlinear program-


programming algorithm for con-


ming for the crying baby problem with