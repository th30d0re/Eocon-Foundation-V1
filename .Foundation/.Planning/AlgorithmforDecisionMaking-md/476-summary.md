---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 58_



Representing uncertainty as a probability distribution is motivated by a set of


axioms related to the comparison of the plausibility of different statements.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


2.7. summary


37


Example 2.8. Conditional indepen-


Suppose that we want to determine whether the network shown in the margin


dence assumptions implied by the


implies that


. There are two undirected paths from


to


. We


graphical structure below.


need to check both paths for d-separation.


The path


involves the fork


, followed


by an inverted fork,


. There is no evidence at


, so there is


no d-separation from the fork. Since


is a descendant of


, there is no d-


separation along the inverted fork. Hence, there is no d-separation along this


path.


The second path,


, involves the inverted fork


and a chain,


. Since


is a descendant of


, there is no d-separation


along the inverted fork. Because there is no d-separation along the chain part


of this path either, there is no d-separation along this path from


to


For


and


to be conditionally independent given


, there must be d-


separation along all undirected paths from


to


. In this case, neither of the


two paths has d-separation. Hence, conditional independence is not implied


by the network structure.


There are many families of both discrete and continuous probability distribu-


tions.


Continuous probability distributions can be represented by density functions.


Probability distribution families can be combined in mixtures to create more


flexible distributions.


• Joint distributions are distributions over multiple variables.


Conditional distributions are distributions over one or more variables given


the values of evidence variables.


A Bayesian network is defined by a graphical structure and a set of conditional


distributions.


Depending on the structure of the Bayesian network, we can represent joint


distributions with fewer parameters due to conditional independence assump-


tions.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


38


chapter 2. representation