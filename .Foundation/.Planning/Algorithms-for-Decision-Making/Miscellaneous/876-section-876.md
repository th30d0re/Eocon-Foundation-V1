---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: '&& !'
---

# && !

_Source page: 127_



has_edge


&&


has_edge


&&


has_edge


))


return false


end


end


end


end


return true


end


Figure 5.5. A Markov equivalence


Markov equivalence class


Member


class and examples of members


and a nonmember. The nonmem-


ber does not belong to the Markov


equivalence class because it in-


troduces an immoral v-structure,


, which is not in-


dicated in the partially directed


graph.


Member


Nonmember


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


106


chapter 5. structure learning


Instead of searching the space of directed acyclic graphs, we can search the


Details of how to search this


space of Markov equivalence classes represented by partially directed graphs.


space are provided by D. M. Chick-


Although the space of Markov equivalence classes is, of course, smaller than the


ering,


“Learning


Equivalence


space of directed acyclic graphs, it is not significantly smaller; the ratio of directed


Classes of Bayesian-Network Struc-


10


tures,”


Journal of Machine Learning


acyclic graphs to equivalence classes asymptotes to around


3.7


fairly quickly.


Research


, vol. 2, pp. 445–498, 2002.


A problem with hill climbing in the space of directed acyclic graphs is that the


10


S. B. Gillispie and M. D. Perlman,


neighborhood may consist of other graphs that are in the same equivalence


“The Size Distribution for Markov


Equivalence Classes of Acyclic Di-


class with the same score, which can lead to the search becoming stuck in a local


graph Models,”


Artificial Intelli-


optimum. Searching the space of equivalence classes allows us to jump to different


gence


, vol. 141, no. 1–2, pp. 137–155,


directed acyclic graphs outside the current equivalence class.


2002.


Any of the general search strategies presented in section 5.2 can be used. If a


form of local search is used, then we need to define the local graph operations


that define the neighborhood of the graph. Examples of local graph operations


include:


• If an edge between


and


does not exist, add either


or


• If


or


, then remove the edge between


and


• If


, then reverse the direction of the edge to get


• If


, then add


To score a partially directed graph, we generate a member of its Markov equiva-


lence class and compute its score.