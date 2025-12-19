---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 112_



4.2


We compute this distribution for all the instances in our data set. For the


weighted completions, we can obtain a new estimate for


. We estimate


by taking the mean across the instances in our data set. To estimate


and


, we use the mean and standard deviation of the values for


over the


instances in our data set, weighted by the probability of


associated with


the various instances.


We repeat the process until convergence occurs. The plot here shows three


iterations. The histogram was generated from the values of


. The dark blue


function indicates the inferred density. By the third iteration, our parameters


of the Gaussian mixture model closely represent the data distribution.


Iteration


Iteration


Iteration


0.4


0.2


10


10


10


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


4.6. exercises


91


Solution:


We denote the probability of making a basket as


. Since we start with a uniform


prior


Beta