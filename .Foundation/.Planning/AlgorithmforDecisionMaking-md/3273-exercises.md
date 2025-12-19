---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 533_



Exercise 24.1.


Give an example of a game with two agents and an infinite number of


actions such that a Nash equilibrium does not exist.


Solution:


Suppose that the action space of each agent consists of the negative real numbers


and their reward is equal to their action. Since no greatest negative number exists, a Nash


equilibrium cannot exist.


Exercise 24.2.


Give an example of a game with two agents, two actions, and two Nash


equilibria involving deterministic policies.


19


19


This example comes from M. J.


Solution:


Here is one example.


Suppose that we have two aircraft on a collision course,


Kochenderfer,


Decision Making Un-


and the pilots of each aircraft must choose between climb or descend to avoid collision. If


der Uncertainty: Theory and Applica-


the pilots both choose the same maneuver, then there is a crash, with utility


to both


tion


. MIT Press, 2015.


pilots. Because climbing requires more fuel than descending, there is an additional penalty


of


to any pilot who decides to climb.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


512


chapter 24. multiagent reasoning


agent


descend


climb


5,