---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Cross Entropy Method
---

# Cross Entropy Method

_Source page: 240_



for Fast Policy Search,” in


Interna-


tional Conference on Machine Learn-


ing (ICML)


, 2003.


The


cross entropy method


(algorithm 10.4) involves updating a


search distribution


over the parameterized space of policies at each iteration.


We parameterize this


Often,


search distribution


with


This distribution can belong to any family,


and


are vectors, but


because this assumption is not re-


but a Gaussian distribution is a common choice, where


represents the mean and


quired for this method, we will not


bold them in this section.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


10.5. evolution strategies


219


Figure 10.4. Genetic policy search


with