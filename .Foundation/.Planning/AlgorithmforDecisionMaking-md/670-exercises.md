---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 88_



Exercise 3.1.


Given the following Bayesian network and its associated conditional proba-


bility distributions, write the equation required to perform exact inference for the query


Solution:


We first expand the inference expression using the definition of conditional


probability.


) =


We can rewrite the numerator as a marginalization over the hidden variables and we can


rewrite the denominator as a marginalization over both the hidden and query variables:


) =


The definition of the joint probability in both the numerator and the denominator can be


rewritten using the chain rule for Bayesian networks and the resulting equation can be


simplified by removing constants from inside the summations:


) =


Exercise 3.2.


Given the following Bayesian network and its associated conditional proba-


bility distributions, write the equation required to perform an exact inference for the query


Solution:


We first expand the inference expression using the definition of conditional


probability:


) =


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


3.11. exercises


67


We can rewrite the numerator as a marginalization over the hidden variables, and we can


rewrite the denominator as a marginalization over both the hidden and query variables:


) =


The definition of the joint probability in both the numerator and the denominator can be


rewritten using the chain rule for Bayesian networks, and the resulting equation can be


simplified by removing constants from inside the summations. Note that there are multiple


possible orderings of the summations in the final equation:


) =


Exercise 3.3.


Suppose that we are developing an object detection system for an autonomous


vehicle driving in a city. Our vehicle’s perception system reports an object’s size


(either


small, medium, or large) and speed


(either slow, moderate, or fast). We want to design


a model that will determine the class


of an object—either a vehicle, pedestrian, or a


ball—given observations of the object’s size and speed. Assuming a naive Bayes model


with the following class prior and class-conditional distributions, what is the detected


class given observations


= medium and


= slow?


vehicle