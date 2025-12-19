---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Bayesian Parameter Learning
---

# Bayesian Parameter Learning

_Source page: 97_



Bayesian parameter learning


addresses some of the drawbacks of maximum like-


lihood estimation, especially when the amount of data is limited. For example,


suppose that our aviation safety database was limited to the events of the past


week, and we found no recorded midair collisions. If


is the probability that a


flight results in a midair collision, then the maximum likelihood estimate would


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


76


chapter 4. parameter learning


Example


4.1.


Using


the


Suppose that we have a small network,


, and we want to extract


statistics


function


for


ex-


the statistics from data matrix


. We can use the following code:


tracting the statistics from a data


SimpleDiGraph


set. Bayesian parameter learning


add_edge!


can be used to avoid


nan


values,


add_edge!


but we must specify a prior.


vars


Variable


),


Variable


),


Variable


)]