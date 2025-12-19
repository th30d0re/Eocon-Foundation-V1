---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ))
---

# ))

_Source page: 55_



, where


Pa


represents the parents of


tionships between variables. How-


in the graph. Algorithm 2.2 provides an implementation of a Bayesian network


ever, causality is not required in


general Bayesian networks. J. Pearl,


data structure. Example 2.5 illustrates the application of Bayesian networks to a


Causality: Models, Reasoning, and In-


satellite-monitoring problem.


ference


, 2nd ed. Cambridge Univer-


sity Press, 2009.


Algorithm 2.2. A discrete Bayesian


struct


BayesianNetwork


network representation in terms of


vars


::


Vector


Variable


a set of variables, factors, and a


factors


::


Vector


Factor


graph. The graph data structure is


graph


::


SimpleDiGraph


Int64


provided by


Graphs.jl


end


The


chain rule


for Bayesian networks specifies how to construct a joint distribu-


tion from the local conditional probability distributions. Suppose that we have


the variables


1:


and want to compute the probability of a particular assignment


of all these variables to values


. The chain rule says


1: