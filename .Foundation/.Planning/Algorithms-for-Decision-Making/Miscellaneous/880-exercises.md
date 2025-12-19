---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 129_



Exercise 5.1.


How many neighbors does an edgeless directed acyclic graph with


nodes


have?


Solution:


Of the three basic graph operations, we can only add edges. We can add any edge to


an edgeless directed acyclic graph and it will remain acyclic. There are


) =


node pairs, and therefore that many neighbors.


Exercise 5.2.


How many networks are in the neighborhood of the following Bayesian


network?


Solution:


We can perform the following graph operations:


• Add


• Remove


• Flip


Thus, there are


10


Bayesian networks in the neighborhood.


Exercise 5.3.


Suppose we start local search with a Bayesian network


. What is the fewest


number of iterations of local search that could be performed to converge to the optimal


Bayesian network


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


108


chapter 5. structure learning


Solution:


At each iteration, local search can move from the original network to a network in


its neighborhood, which is at most one edge operation from the original network. Since


there are three differences between the edges of


and


, performing local search from


would require a minimum of three iterations to arrive at


. One potential minimal


sequence of local search iterations could be flipping


, removing


, and adding


. We assume that the graphs formed with these edge operations yielded the highest


Bayesian scores of all graphs in the considered neighborhood.


Exercise 5.4.


Draw the partially directed acyclic graph representing the Markov equiv-


alence class of the following Bayesian network. How many graphs are in this Markov


equivalence class?


Solution:


The Markov equivalence class can be represented by the following partially


directed acyclic graph:


There are six networks in this Markov equivalence class, which are shown here:


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


5.6. exercises


109


Exercise 5.5.


Give an example of a partially directed acyclic graph with four nodes that


does not define a nonempty Markov equivalence class.


Solution:


Consider the following partially directed acyclic graph:


We cannot replace the undirected edge with a directed edge because doing so would


introduce a new v-structure.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com