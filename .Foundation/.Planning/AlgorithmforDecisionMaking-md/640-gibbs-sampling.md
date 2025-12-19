---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Gibbs Sampling
---

# Gibbs Sampling

_Source page: 82_



Named for the American scientist


An alternative approach to inference is to use


Gibbs sampling


which is a kind of


Josiah Willard Gibbs (1839–1903),


Markov chain Monte Carlo


technique. Gibbs sampling involves drawing samples


who, with James Clerk Maxwell


consistent with the evidence in a way that does not involve weighting. From these


and Ludwig Boltzman, created the


field of statistical mechanics.


samples, we can infer the distribution over the query variables.


Gibbs sampling involves generating a sequence of samples, starting with an


initial sample,


, generated randomly with the evidence variables set to their


1:


observed values. The


th sample


depends probabilistically on the previous


1:


sample,


. We modify


in place to obtain


as follows. Using any


1:


1:


1:


ordering of the unobserved variables, which need not be a topological sort,


is


sampled from the distribution represented by


. Here,


represents


the values of all other variables except


. Sampling from


in sample


can be done efficiently because we only need to consider the Markov blanket of


variable


(see section 2.6).


Unlike the other sampling methods discussed so far, the samples produced


by this method are not independent. However, it can be proven that, in the


limit, samples are drawn exactly from the joint distribution over the unobserved


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


3.8. gibbs sampling


61


variables given the observations. Algorithm 3.9 shows how to compute a factor


for


. Gibbs sampling is implemented in algorithm 3.10.


Algorithm 3.9. A method for ob-


function


blanket


bn


taining


for a Bayesian


name


bn


vars


].


name


network


bn


given a current assign-


val


name


ment


delete!


copy


),


name


filter


->


in_scope


name


),


bn


factors


prod


condition


for


in


return


normalize!


end


Gibbs sampling can be applied to our running example. We can use our


samples to estimate