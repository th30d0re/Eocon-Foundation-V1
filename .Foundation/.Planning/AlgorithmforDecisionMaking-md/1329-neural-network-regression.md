---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Neural Network Regression
---

# Neural Network Regression

_Source page: 196_



Neural network regression


relieves us of having to construct an appropriate set of


basis functions as required in linear regression. Instead, a


neural network


is used


to represent our value function. For a review of neural networks, see appendix D.


The input to the neural network would be the state variables, and the output


would be the utility estimate. The parameters


would correspond to the


weights


in the neural network.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


8.8. summary


175


Algorithm 8.6. Linear regression


mutable struct


LinearRegressionValueFunction


value function approximation, de-


# basis vector function


fined by a basis vector function


# vector of parameters


and a vector of parameters


end


The function


pinv


implements the


psuedoinverse. Julia and other lan-


function


Uθ


::


LinearRegressionValueFunction


)(


return


Uθ


Uθ


guages support the


backslash


opera-


end


tor, which allows us to write


in place of


pinv


in the


fit!


function


fit!


Uθ


::


LinearRegressionValueFunction


function.


hcat


([


Uθ


for


in