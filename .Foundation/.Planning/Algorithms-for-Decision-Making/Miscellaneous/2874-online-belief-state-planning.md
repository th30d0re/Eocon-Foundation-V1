---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Online Belief State Planning
---

# Online Belief State Planning

_Source page: 475_



Online methods determine the optimal policy by planning from the current belief


state. The belief space reachable from the current state is typically small compared


with the full belief space. As introduced in the fully observable context, many


online methods use variations of tree-based search up to some horizon.


Various


survey


is


provided


by


S.


Ross, J. Pineau, S. Paquet, and


strategies can be used to try to avoid the exponential computational growth with


B. Chaib-draa, “Online Planning


the tree depth. Although online methods require more computation per decision


Algorithms for POMDPs,”


Journal


of Artificial Intelligence Research


step during execution than offline approaches, online methods are sometimes


vol. 32, pp. 663–704, 2008.


easier to apply to high-dimensional problems.