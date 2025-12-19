---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Markov Equivalence Classes
---

# Markov Equivalence Classes

_Source page: 125_



As discussed earlier, the structure of a Bayesian network encodes a set of con-


ditional independence assumptions. An important observation to make when


trying to learn the structure of a Bayesian network is that two different graphs


can encode the same independence assumptions. As a simple example, the two-


variable network


has the same independence assumptions as


Solely on the basis of the data, we cannot justify the direction of the edge between


and


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


104


chapter 5. structure learning


If two networks encode the same conditional independence assumptions, we


say that they are


Markov equivalent


. It can be proven that two graphs are Markov


equivalent if and only if they have (1) the same edges, without regard to di-


rection; and (2) the same set of immoral v-structures. An


immoral v-structure


is


a v-structure


, with


and


not directly connected, as shown in


figure 5.4. A


Markov equivalence class


is a set containing all the directed acyclic


graphs that are Markov equivalent to each other. A method for checking Markov


equivalence is given in algorithm 5.4.


Figure 5.4. Moral and immoral v-


moral


immoral


structures.


In general, two structures belonging to the same Markov equivalence class may


be given different scores. However, if the Bayesian score is used with Dirichlet


priors such that


, then two Markov equivalent


ijk


is constant for all


This was shown by D. Hecker-


structures are assigned the same score.


Such priors are called


BDe


, and a special


man, D. Geiger, and D. M. Chick-


case is the


BDeu


prior,


which assigns


. Although the commonly


ijk


ering, “Learning Bayesian Net-


used uniform prior


does not always result in identical scores being


works: The Combination of Knowl-


ijk


edge and Statistical Data,”


Machine


assigned to structures in the same equivalence class, they are often fairly close. A


Learning


, vol. 20, no. 3, pp. 197–243,


scoring function that assigns the same score to all structures in the same class is


1995.


W. L. Buntine, “Theory Refine-


called


score equivalent


ment on Bayesian Networks,” in


Conference on Uncertainty in Artifi-


cial Intelligence (UAI)


, 1991.