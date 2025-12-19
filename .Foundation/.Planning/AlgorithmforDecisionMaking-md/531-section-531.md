---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 66_



. The factor product is demonstrated in example 3.1.


We use


factor marginalization


(algorithm 3.2) to sum out a particular variable


from the entire factor table, removing it from the resulting scope. Example 3.2


illustrates this process.


We use


factor conditioning


(algorithm 3.3) with respect to some evidence to


remove any rows in the table inconsistent with that evidence. Example 3.3


demonstrates factor conditioning.


These three factor operations are used together in algorithm 3.4 to perform


exact inference. It starts by computing the product of all the factors, conditioning


on the evidence, marginalizing out the hidden variables, and normalizing. One


potential issue with this approach is the size of the product of all the factors. The


size of the factor product is equal to the product of the number of values each


variable can assume. For the satellite example problem, there are only


32


possible assignments, but many interesting problems would have a factor product


that is too large to enumerate practically.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


3.1. inference in bayesian networks


45


Algorithm 3.1. An implementation


function


Base


:*


::


Factor


::


Factor


of the factor product, which con-


ϕnames


variablenames


structs the factor representing the


ψnames


variablenames


joint distribution of two smaller fac-


ψonly


setdiff


vars


vars


tors


and


. If we want to compute


table


FactorTable


()


the factor product of


and


, we


for


ϕa


ϕp


in


table


simply write


for


in


assignments


ψonly


merge


ϕa


ψa


select


ψnames


table


ϕp


get


table


ψa


0.0


end


end


vars


vcat


vars


ψonly


return


Factor


vars


table


end


Example 3.1.


An illustration of


The factor product of two factors produces a new factor over the union of


a factor product combining two


their variables. Here, we produce a new factor from two factors that share a


factors representing


and


to produce a factor repre-


variable:


senting


0.3


0.4


0.2