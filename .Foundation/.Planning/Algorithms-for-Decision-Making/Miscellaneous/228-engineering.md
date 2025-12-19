---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Engineering
---

# Engineering

_Source page: 32_



The field of engineering has focused on allowing physical systems, such as robots,


to make intelligent decisions. World-renowned roboticist Sebastian Thrun de-


scribes the components of these systems as follows:


19


S. Thrun, “Probabilistic Robot-


ics,”


Communications of the ACM


Robotics systems have in common that they are situated in the physical world,


vol. 45, no. 3, pp. 52–57, 2002.


perceive their environments through sensors, and manipulate their environment


19


through things that move.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


1.4. history


11


To design these systems, engineers must address perception, planning, and acting.


Physical systems perceive the world by using their sensors to create a representa-


tion of the salient features of their environment. The field of state estimation has


focused on using sensor measurements to construct a belief about the state of the


world. Planning requires reasoning about the ways to execute the tasks they are


designed to perform. The planning process has been enabled by advances in the


20


20


G. E. Moore, “Cramming More


semiconductor industry spanning many decades.


Once a plan has been devised,


Components onto Integrated Cir-


an autonomous agent must act on it in the real world. This task requires both


cuits,”


Electronics


, vol. 38, no. 8,


hardware (in the form of actuators) and algorithms to control the actuators and


pp. 114–117, 1965.


reject disturbances. The field of control theory has focused on the stabilization


21


21


D. A. Mindell,


of mechanical systems through feedback control.


Automatic control systems


Between Human


and Machine: Feedback, Control, and


are widely used in industry, from the regulation of temperature in an oven to the


Computing Before Cybernetics