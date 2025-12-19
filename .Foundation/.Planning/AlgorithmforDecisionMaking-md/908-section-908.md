---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 136_



. We define the


lottery


to be


: 1


. To determine


, we must


find


such that


. Similarly, to determine


, we find


such that


It may be tempting to use monetary values to infer utility functions. For exam-


ple, if we are building a decision support system for managing wildfires, it may


be tempting to define a utility function in terms of the monetary cost incurred by


property damage and the monetary cost for deploying fire suppression resources.


However, it is well known in economics that the utility of wealth, in general, is


H. Markowitz, “The Utility of


not linear.


If there were a linear relationship between utility and wealth, then


Wealth,”


Journal of Political Econ-


decisions should be made in terms of maximizing expected monetary value.


omy


, vol. 60, no. 2, pp. 151–158,


Someone who tries to maximize expected monetary value would have no use


1952.


for insurance because the expected monetary values of insurance policies are


generally negative.


Instead of trying to maximize expected wealth, we generally want to maximize


the expected utility of wealth. Of course, different people have different utility


functions. Figure 6.1 shows an example of a utility function. For small amounts


of wealth, the curve is roughly linear, where $100 is about twice as good at $50.


For larger amounts of wealth, however, the curve tends to flatten out; after all,


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


6.3. utility elicitation


115


$1000 is worth less to a billionaire than it is to the average person. The flattening


of the curve is sometimes referred to as


diminishing marginal utility


When discussing monetary utility functions, the three terms listed here are


often used. To illustrate this, assume that


represents being given $50 and


represents a