---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 58_



. Interestingly, if the directions of the arrows were


slightly different, with


(inverted fork), then


and


may no


longer be conditionally independent given


. In other words, it may be the


case that


. To provide some intuition, consider the


inverted fork path from battery failure


to solar panel failure


via electrical


system failure


. Suppose we know that we have an electrical failure. If we


know that we do not have a battery failure, then we are more inclined to


believe that we have a solar panel failure because it is an alternative cause of


the electrical failure. Conversely, if we found out that we do have a battery


failure, then our belief that we have a solar panel failure decreases. This effect


is referred to as


explaining away


. Observing a solar panel failure explains


away the cause of the electrical system failure.


21


21


Named after the Russian math-


Sometimes the term


Markov blanket


of node


is used to refer to the minimal


ematician Andrey Andreyevich


set of nodes that, if their values were known, make


conditionally independent


Markov (1856–1922). J. Pearl,


Prob-


of all other nodes. A Markov blanket of a particular node turns out to consist of


abilistic Reasoning in Intelligent Sys-


tems: Networks of Plausible Inference


its parents, its children, and the other parents of its children.


Morgan Kaufmann, 1988.