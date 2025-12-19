---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Distributed Wildfire Surveillance
---

# Distributed Wildfire Surveillance

_Source page: 26_



Situational awareness is a major challenge when fighting wildfires. The state of a


This application was explored by


fire evolves over time, influenced by factors such as wind and the distribution


K. D. Julian and M. J. Kochender-


of fuel in the environment. Many wildfires span large geographic regions. One


fer, “Distributed Wildfire Surveil-


lance with Autonomous Aircraft


concept for monitoring a wildfire is to use a team of drones equipped with


Using Deep Reinforcement Learn-


sensors to fly above it.


The sensing range of individual drones is limited, but


ing,”


AIAA Journal of Guidance, Con-


trol, and Dynamics


, vol. 42, no. 8,


the information from the team can be fused to provide a unified snapshot of the


pp. 1768–1778, 2019.


situation to drive resource allocation decisions. We would like the team members


to autonomously determine how to collaborate with each other to provide the best


coverage of the fire. Effective monitoring requires deciding how to maneuver to


cover areas where new sensor information is likely to be useful; spending time in


areas where we are certain of whether the fire is burning or not would be wasteful.


Identifying important areas to explore requires reasoning about the stochastic


evolution of the fire, given only imperfect knowledge of its current state.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


1.3. methods