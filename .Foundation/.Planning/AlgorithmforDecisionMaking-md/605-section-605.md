---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 78_



0.5


. Of course, we would want to use more than just 2


samples to accurately estimate


Algorithm 3.7.


The direct sam-


struct


DirectSampling


pling inference method, which


# number of samples


takes a Bayesian network


bn


, a


end


list of query variables


query


, and


evidence


evidence


. The method


function


infer


::


DirectSampling


bn


query


evidence


draws


samples from the Bayesian


table


FactorTable


()


for


in 1


network and retains those samples


rand


bn


that are consistent with the evi-


if


all


==


for


in


pairs


evidence


))


dence. A factor over the query vari-


select


query


ables is returned. This method can


table


get


table


fail if no samples that satisfy the


end


evidence are found.


end


vars


filter


->


name


query


bn


vars


return


normalize!


Factor


vars


table


))


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


3.7. likelihood weighted sampling


57