---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Recurrent Networks
---

# Recurrent Networks

_Source page: 610_



The neural network architectures discussed so far are ill suited for temporal


or sequential inputs. Operations on sequences occur when processing images


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


d.5. recurrent networks


589


from videos, when translating a sequence of words, or when tracking time-series


data. In such cases, the outputs depend on more than just the most recent input.


In addition, the neural network architectures discussed so far do not naturally


produce variable-length outputs. For example, a neural network that writes an


essay would be difficult to train using a conventional, fully connected neural


network.


Figure D.8.


Traditional neural


, . . .


, . . .


networks do not naturally accept


variable-length inputs or produce


variable-length outputs.


neural network


neural network


neural network


, . . .


, . . .


many-to-one


one-to-many


many-to-many


When a neural network has sequential input, sequential output, or both (fig-


ure D.8), we can use a


recurrent neural network


to act over multiple iterations.


These neural networks maintain a recurrent state


, sometimes called its


memory


to retain information over time. For example, in translation, a word used early in


a sentence may be relevant to the proper translation of words later in the sentence.


Figure D.9 shows the structure of a basic recurrent neural network and how the


same neural network can be understood to be a larger network unrolled in time.


Figure D.9. A recurrent neural net-


work (left) and the same recurrent


neural network unrolled in time


neural network


neural network


(right). These networks maintain a


recurrent state


that allows the net-


work to develop a sort of memory,


neural network


transferring information across it-


erations.


neural network


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


590


appendix d. neural representations


This unrolled structure can be used to produce a rich diversity of sequential


neural networks, as shown in figure D.10. Many-to-many structures come in mul-


tiple forms. In one form, the output sequence begins with the input sequence. In


another form, the output sequence does not begin with the input sequence. When


using variable-length outputs, the neural network output itself often indicates


when a sequence begins or ends. The recurrent state is often initialized to zero, as


are extra inputs after the input sequence has been passed in, but this need not be


the case.


many-to-many


one-to-many


many-to-one


many-to-many


Figure D.10. A recurrent neural


network can be unrolled in time


Recurrent neural networks with many layers, unrolled over multiple time steps,


to produce different relationships.


Unused or default inputs and out-


effectively produce a very deep neural network. During training, gradients are


puts are grayed out.


computed with respect to the loss function. The contribution of layers farther from


the loss function tends to be smaller than that of layers close to the loss function.


This leads to the


vanishing gradient


problem, in which deep neural networks have


vanishingly small gradients in their upper layers. These small gradients slow


training.


Very deep neural networks can also suffer from


exploding gradients


, in which


successive gradient contributions through the layers combine to produce very


large values. Such large values make learning unstable. Example D.4 shows both


exploding and vanishing gradients.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


d.5. recurrent networks


591


Example D.4.


A demonstration


To illustrate vanishing and exploding gradients, consider a deep neural net-


of how vanishing and exploding


work made of one-dimensional, fully connected layers with relu activations.


gradients arise in deep neural net-


works. This example uses a very


For example, if the network has three layers, its output is


simple neural network. In larger,


fully connected layers, the same