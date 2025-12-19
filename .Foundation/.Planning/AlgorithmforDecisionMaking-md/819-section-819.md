---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 110_



0.2


1/3


The


in the calculation here is a normalization constant, which enforces that


each instance is expanded to instances whose weights sum to


. The count


matrices are then


0.8


2/3


1.2


2/3


1/3


1/3


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


4.5. summary


89


and


is discrete and can take on one of three values. Our model assumes


is conditional Gaussian. Our data set contains only values for


, but none for


. We start with an initial


and use it to infer a probability distribution over


the values of


, given the value of


for each instance. The distribution over


entry completions are then used to update our estimate of the parameters of


and


as illustrated in example 4.4. We iterate to convergence, which


often occurs very quickly. The parameters that we obtain in this example define a


Gaussian mixture model, which was introduced in section 2.2.2.