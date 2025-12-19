---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Neural Networks
---

# Neural Networks

_Source page: 603_



ing


. Several textbooks are dedi-


cated entirely to these techniques,


neural network


is a differentiable function


that maps inputs


to


including I. Goodfellow, Y. Bengio,


and A. Courville,


Deep Learning


produce outputs


and is parameterized by


. Modern neural networks may


MIT Press, 2016. The Julia package


have millions of parameters and can be used to convert inputs in the form of


Flux.jl


provides efficient imple-


mentations of various learning al-


high-dimensional images or video into high-dimensional outputs like multidi-


gorithms.


mensional classifications or speech.


The parameters of the network


are generally tuned to minimize a scalar


loss


function


that is related to how far the network output is from the desired


output. Both the loss function and the neural network are differentiable, allowing


us to use the gradient of the loss function with respect to the parameterization


to iteratively improve the parameterization. This process is often referred to


as neural network


training


or


parameter tuning


. It is demonstrated in example D.1.


Neural networks are typically trained on a data set of input-output pairs


. In


this case, we tune the parameters to minimize the aggregate loss over the data


set:


arg min