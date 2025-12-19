---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Partially Directed Graph Search
---

# Partially Directed Graph Search

_Source page: 126_



A Markov equivalence class can be represented as a


partially directed graph


, some-


times called an


essential graph


or a


directed acyclic graph pattern


. A partially directed


graph can contain both directed edges and undirected edges. An example of a


partially directed graph that encodes a Markov equivalence class is shown in


figure 5.5. A directed acyclic graph


is a member of the Markov equivalence


class encoded by a partially directed graph


if and only if


has the same edges


as


without regard to direction and has the same immoral v-structures as


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


5.4. partially directed graph search


105


Algorithm 5.4. A method for de-


function


are_markov_equivalent


termining whether the directed


if


nv


!=


nv


||


ne


!=


ne


||


acyclic graphs


and


are Markov


all


has_edge


||


has_edge


reverse


))


equivalent. The


subsets


function


for


in


edges


))


from


IterTools.jl


returns all sub-


return false


sets of a given set and a specified


end


size.


for


in


[(