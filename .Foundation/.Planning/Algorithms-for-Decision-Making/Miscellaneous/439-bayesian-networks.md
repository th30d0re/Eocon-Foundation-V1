---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Bayesian Networks
---

# Bayesian Networks

_Source page: 54_



graph terminology.


15


Bayesian network


can be used to represent a joint probability distribution.


The


structure of a Bayesian network is defined by a


directed acyclic graph


consisting of


16


nodes and directed edges.


Each node corresponds to a variable. Directed edges


connect pairs of nodes, with cycles in the graph being prohibited. The directed


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


2.5. bayesian networks


33


17


17


In


edges indicate direct probabilistic relationships.


Associated with each node


causal networks


, the direction


is


of the edges indicate causal rela-


a conditional distribution


Pa