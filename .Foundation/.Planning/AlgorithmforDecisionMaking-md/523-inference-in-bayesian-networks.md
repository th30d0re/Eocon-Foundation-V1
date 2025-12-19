---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Inference in Bayesian Networks
---

# Inference in Bayesian Networks

_Source page: 65_



In inference problems, we want to infer a distribution over


query variables


given


some observed


evidence variables


. The other nodes are referred to as


hidden variables


We often refer to the distribution over the query variables, given the evidence, as


posterior distribution


To illustrate the computations involved in inference, recall the Bayesian network


from example 2.5, the structure of which is reproduced in figure 3.1. Suppose we


have


as a query variable and evidence


and


. The inference task is to


compute


, which corresponds to computing the probability that we


have a battery failure given an observed trajectory deviation and communication


loss.


From the definition of conditional probability introduced in equation (2.22),


we know that