---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Parameter Learning
---

# Parameter Learning

_Source page: 93_



This chapter focuses on learn-


We have assumed so far that the parameters and structure of our probabilistic


ing model parameters from data,


models were known. This chapter addresses the problem of


learning


or


fitting


which is an important component


model parameters from data.


We begin by introducing an approach where we


of the field of


machine learning


. A


broad introduction to the field is


identify the parameters of a model that maximize the likelihood of observing


provided by K. P. Murphy,


Proba-


the data. After discussing the limitations of such an approach, we introduce an


bilistic Machine Learning: An Intro-


duction


. MIT Press, 2022.


alternative Bayesian approach, in which we start with a probability distribution


over the unknown parameters and then update that distribution based on the


observed data using the laws of probability. We then discuss probabilistic models


that avoid committing to a fixed number of parameters.