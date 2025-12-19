---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 439_



plans


value_iteration


k_max


return


LookaheadAlphaVectorPolicy


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


418


chapter 20. exact belief state planning


Figure 20.3. POMDP value itera-


-step plans


-step plans


-step plans


tion used to find the optimal value


function for the crying baby prob-


lem to various horizons.


10


10


10


20


20


20


0.2


0.6


0.8


0.2


0.6


0.8


0.2


0.6


0.8


0.4


0.4


0.4


-step plans


-step plans


-step plans


10


10


10


20


20


20


0.2


0.6


0.8


0.2


0.6


0.8


0.2


0.6


0.8


0.4


0.4


0.4


hungry


hungry


hungry


ignore


sing


feed


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


20.6. linear policies


419


subplan


The expansion step (algorithm 20.9) in this process constructs all possible


-step plans from a set of


-step plans. New plans can be constructed using


subplan


a new first action and all possible combinations of the


-step plans as subplans, as


...


|O|


shown in figure 20.4. While plans can also be extended by adding actions to the


ends of subplans, top-level expansion allows alpha vectors constructed for the


subplan


-step plans to be used to efficiently construct alpha vectors for the


-step


Figure 20.4. A


-step plan


can be constructed using a new ini-


plans.


tial action leading to any combina-


Computing the alpha vector associated with a plan


from a set of alpha vectors


tion of


-step subplans.


associated with its subplans can be done as follows. We use


to represent the


alpha vector associated with subplan


. The alpha vector associated with


is


then