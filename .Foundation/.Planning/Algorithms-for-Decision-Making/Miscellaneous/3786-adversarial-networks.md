---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Adversarial Networks
---

# Adversarial Networks

_Source page: 616_



We often want to train neural networks to produce high-dimensional outputs,


such as images or sequences of helicopter control inputs. When the output space is


large, the training data may cover only a very small region of the state space. Hence,


training purely on the available data can cause unrealistic results or overfitting.


We generally want the neural network to produce plausible outputs. For example,


when producing images, we want the images to look realistic. When mimicking


human driving, such as in imitation learning (chapter 18), we want the vehicle to


typically stay in its lane and to react appropriately to other vehicles.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


d.7. adversarial networks


595


Example D.5.


A visualization


We can use an autoencoder to train an embedding for the MNIST data set.


of a two-dimensional embedding


In this example, we use an encoder similar to the convolutional network in


learned for the MNIST digits.


example D.3, except with a two-dimensional output and no softmax layer.


We construct a decoder that mirrors the encoder and train the full network to


minimize the reconstruction loss. Here are the encodings for