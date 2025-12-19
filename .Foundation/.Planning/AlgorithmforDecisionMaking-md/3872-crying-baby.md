---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Crying Baby
---

# Crying Baby

_Source page: 637_



The


crying baby problem


is a simple POMDP with two states, three actions, and


two observations. Our goal is to care for a baby, and we do so by choosing at each


The version of the crying baby


time step whether to feed the baby, sing to the baby, or ignore the baby.


problem presented in this text is


The baby becomes hungry over time. We do not directly observe whether the


an extension of the original, sim-


baby is hungry; instead, we receive a noisy observation in the form of whether


pler crying baby problem in M. J.


Kochenderfer,


Decision Making Un-


the baby is crying. The state, action, and observation spaces are as follows:


der Uncertainty: Theory and Applica-


tion


. MIT Press, 2015.


sated


hungry


feed


sing


ignore


crying


quiet


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


616


appendix f. problems


Figure F.9. Optimal value function


0.0


m/s


5.0


m/s


slices (top) and policy slices (bot-


200


tom) for the aircraft collision avoid-


ance problem. The value function


0.2


and policy are symmetric about


100


when the vertical separation rate is


0.4


, but are skewed when the vertical


separation rate is nonzero. Overall,


0.6


our aircraft need not take action un-


til the intruder aircraft is close.


100


0.8


200


200


no advisory


descend


100


climb


100


200


20


30


20


30


10


40


10


40


col


col


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


f.8. machine replacement


617


Feeding will always sate the baby. Ignoring the baby risks a sated baby be-


coming hungry, and ensures that a hungry baby remains hungry. Singing to the


baby is an information-gathering action with the same transition dynamics as


ignoring, but without the potential for crying when sated (not hungry) and with


an increased chance of crying when hungry.


The transition dynamics are as follows:


sated


hungry


feed