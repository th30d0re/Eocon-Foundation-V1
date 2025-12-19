---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Aircraft Collision Avoidance
---

# Aircraft Collision Avoidance

_Source page: 25_



To help prevent midair collisions between aircraft, we want to design a system


that can alert pilots to potential threats and direct them how to maneuver to


This application is discussed in


avoid them.


The system communicates with the transponders of other aircraft


a chapter titled ‘‘Collision Avoid-


to identify their positions with some degree of accuracy. Deciding what guidance


ance’’ by M. J. Kochenderfer,


De-


to provide to the pilots is challenging. There is uncertainty in how quickly the


cision Making Under Uncertainty:


Theory and Application


. MIT Press,


pilots will respond and how aggressively they will comply with the guidance.


2015.


In addition, there is uncertainty in the behavior of other aircraft. We want our


system to alert sufficiently early to provide enough time for pilots to maneuver


their aircraft to avoid collisions, but we do not want our system to issue alerts too


early, which would result in many unnecessary maneuvers. Since this system is to


be used continuously worldwide, we need the system to provide an exceptional


level of safety.