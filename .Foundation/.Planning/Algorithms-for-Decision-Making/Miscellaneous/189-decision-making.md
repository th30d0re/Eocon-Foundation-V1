---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Decision Making
---

# Decision Making

_Source page: 23_



An


agent


is an entity that acts based on observations of its environment. Agents


may be physical entities, like humans or robots, or they may be nonphysical enti-


ties, such as decision support systems that are implemented entirely in software.


As shown in figure 1.1, the interaction between the agent and the environment


follows an


observe-act cycle


or


loop


The agent at time


receives an


observation


of the environment, denoted as


Observations may be made, for example, through a biological sensory process,


as in humans, or by a sensor system, like radar in an air traffic control system.


Observations are often incomplete or noisy; humans may not see an approaching


aircraft or a radar system might miss a detection due to electromagnetic interfer-


ence. The agent then chooses an action


through some decision-making process.


chapter 1. introduction


Figure 1.1. Interaction between an


Observation (


agent and its environment.


Agent


Environment


Action (


This action, such as sounding an alert, may have a nondeterministic effect on the


environment.


Our focus is on agents that interact intelligently to achieve their objectives over


time. Given the past sequence of observations,