---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: (EMNLP)
---

# (EMNLP)

_Source page: 614_



dimensional space in which it is presented. Pixels in images tend to be highly


2014.


11


Such dimensionality reduction


correlated with their neighbors, and point clouds often have many regions of


can also be done using traditional


continuity. Sometimes we wish to build an understanding of the information


machine learning techniques, such


content of our data sets by converting them to a much smaller set of features,


as principal component analysis.


Neural models allow more flexibil-


or an


embedding


. This compression, or


representation learning


, has many advan-


ity and can handle nonlinear rep-


11


tages.


Lower-dimensional representations can help facilitate the application of


resentations.


traditional machine learning techniques like Bayesian networks to what would


have otherwise been intractable. The features can be inspected to develop an


understanding of the information content of the data set, and these features can


be used as inputs to other models.


An


autoencoder


is a neural network trained to discover a low-dimensional feature


encoder


representation of a higher-level input. An autoencoder network takes in a high-


encoding


dimensional input


and produces an output


with the same dimensionality. We


design the network architecture to pass through a lower-dimensional intermediate


representation called a


bottleneck


. The activations


at this bottleneck are our low-


dimensional features, which exist in a


latent space


that is not explicitly observed.


decoder


Such an architecture is shown in figure D.11.


We train the autoencoder to reproduce its input. For example, to encourage the


output


to match


as closely as possible, we may simply minimize the


-norm,


Figure D.11.


An autoencoder


passes a high-dimensional input


minimize