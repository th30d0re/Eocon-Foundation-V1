---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Graphs.jl
---

# Graphs.jl

_Source page: 668_



We use the


Graphs.jl


package (version 1.4) to represent graphs and perform


operations on them:


julia>


using


Graphs


julia>


SimpleDiGraph(


);


# create a directed graph with three nodes


julia>


add_edge!(G,


);


# add edge from node 1 to 3


julia>


add_edge!(G,


);


# add edge from node 1 to 2


julia>


rem_edge!(G,


);


# remove edge from node 1 to 3


julia>


add_edge!(G,


);


# add edge from node 2 to 3


julia>


typeof(G)


Graphs.SimpleGraphs.SimpleDiGraph{Int64}


julia>


nv(G)


# number of nodes (also called vertices)


julia>


outneighbors(G,


# list of outgoing neighbors for node 1


1-element Vector{Int64}:


julia>


inneighbors(G,


# list of incoming neighbors for node 1


Int64[]