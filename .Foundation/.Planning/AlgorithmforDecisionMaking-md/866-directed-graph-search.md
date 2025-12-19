---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Directed Graph Search
---

# Directed Graph Search

_Source page: 121_



In a


directed graph search


, we search the space of directed acyclic graphs for one that


maximizes the Bayesian score. The space of possible Bayesian network structures


18


R. W. Robinson, “Counting La-


grows superexponentially.


With


10


nodes, there are


4.2


10


possible directed


beled Acyclic Digraphs,” in


Ann


72


acyclic graphs. With


20


nodes, there are


2.3


10


. Except for Bayesian networks


Arbor Conference on Graph Theory


with few nodes, we cannot enumerate the space of possible structures to find


1973.


the highest-scoring network. Therefore, we have to rely on a search strategy.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


100


chapter 5. structure learning


Figure 5.3. Bayesian network struc-


ture learning balances model com-


plexity with the available data.


The completely connected model


never outperforms the true model,


whereas the completely uncon-


10


nected model eventually underper-


forms when more than about


10


samples have been drawn. This


20


result indicates that simpler mod-


els can outperform complicated


models when data is scarce—even


when a more complicated model


30


generated the samples.


Completely connected


Bayesian score relative to true model


Completely unconnected