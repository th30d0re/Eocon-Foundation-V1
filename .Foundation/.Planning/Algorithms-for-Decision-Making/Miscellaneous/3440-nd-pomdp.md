---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ND-POMDP
---

# ND-POMDP

_Source page: 569_



is a Dec-POMDP with transition and observation independence and a special


reward structure. The reward structure is represented by a coordination graph. In


contrast with the graphs used earlier in this book, a


coordination graph


is a type of


hypergraph, which allows edges to connect any number of nodes. The nodes in


the ND-POMDP hypergraph correspond to the various agents. The edges relate to


interactions between the agents in the reward function. An ND-POMDP associates


with each edge


in the hypergraph a reward component


that depends on the


state and action components to which the edge connects. The reward function in


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


548


chapter 27. collaborative agents


an ND-POMDP is simply the sum of the reward components associated with the


edges. Figure 27.1 shows a coordination graph resulting in a reward function that


can be decomposed as follows: