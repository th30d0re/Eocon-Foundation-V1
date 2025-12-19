---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 142_



Any of the exact or approximate inference methods introduced in the previ-


ous chapter can be used to evaluate


. To decide whether to apply


a treatment, we compute


EU


and


EU


and make the decision


that provides the highest expected utility.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


6.6. value of information


121


application in example 6.5, we assumed that we have only observed


. Given


the positive result from that one diagnostic test alone, we may decide against


treatment. However, it may be beneficial to administer additional diagnostic tests


to reduce the risk of not treating a disease that is really present.


In computing the value of information, we will use


EU


to denote the


expected utility of an optimal action, given observation


. The value of information


about variable


, given


, is


VOI