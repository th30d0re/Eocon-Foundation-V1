---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Expectation-Maximization
---

# Expectation-Maximization

_Source page: 109_



The


expectation-maximization


EM


) category of approaches involves iterative im-


Expectation-maximization was


provement of the distribution parameter estimate


We begin with an initial


introduced


by


A. P.


Dempster,


which may be a guess, randomly sampled from a prior distribution over distribu-


N. M. Laird, and D. B. Rubin,


tion parameters, or estimated using one of the methods discussed in section 4.4.1.


“Maximum


Likelihood


from


Incomplete


Data


via


the


EM


At each iteration, we perform a two-step process to update


Algorithm,”


Journal of the Royal


The first step is called the


expectation step


E-step


), where we use the current


Statistical Society, Series B (Method-


ological)


, vol. 39, no. 1, pp. 1–38,


estimate of


to infer completions of the data. For example, if we are modeling


1977.


our data using a discrete Bayesian network, we can use one of our inference


algorithms to infer a distribution over the missing entries for each instance. When


extracting the counts, we apply a weighting proportional to the likelihood of the


completions as shown in example 4.3. In cases where there are many missing


variables, there may be too many possible completions to practically enumerate,


making a sampling-based approach attractive. We may also want to use sampling


as an approximation method when our variables are continuous.


The second step is called the


maximization step


M-step


), where we attempt to


find a new


that maximizes the likelihood of the completed data. If we have


a discrete Bayesian network with the weighted counts in the form shown in


example 4.3, then we can perform the same maximum likelihood estimate as


discussed earlier in this chapter. Alternatively, we can use a maximum a posteriori


estimate if we want to incorporate a prior.


This approach is not guaranteed to converge to model parameters that max-


imize the likelihood of the observed data, but it can work well in practice. To


reduce the risk of the algorithm converging to only a local optimum, we can run


the algorithm to convergence from many different initial points in the param-


eter space. We simply choose the resulting parameter estimate in the end that


maximizes likelihood.


Expectation-maximization can even be used to impute values for variables that


are not observed at all in the data. Such variables are called


latent variables


. To


illustrate, suppose we have a Bayesian network


, where


is continuous


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


88


chapter 4. parameter learning


Example 4.3.


Expanding an in-


Suppose that we have a binary Bayesian network with


. We start by


complete data set using assumed


assuming that


implies


model parameters.