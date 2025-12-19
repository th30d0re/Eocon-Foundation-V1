---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Parameter Regularization
---

# Parameter Regularization

_Source page: 607_



Neural networks are typically


underdetermined


, meaning that there are multiple


For example, suppose that we


parameter instantiations that can result in the same optimal training loss.


It


have a neural network with a final


is common to use


parameter regularization


, also called


weight regularization


, to


softmax layer. The inputs to that


introduce an additional term to the loss function that penalizes large parameter


layer can be scaled while produc-


ing the same output, and therefore


values. Regularization also helps prevent


overfitting


, which occurs when a network


the same loss.


over-specializes to the training data but fails to generalize to unseen data.


Regularization often takes the form of an


-norm of the parameterization


vector:


arg min