---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Hierarchical Softmax
---

# Hierarchical Softmax

_Source page: 526_



An area known as


behavioral game theory


aims to model human agents. When


building decision-making systems that must interact with humans, computing


the Nash equilibrium is not always helpful. Humans often do not play a Nash


equilibrium strategy. First, it may be unclear which equilibrium to adopt if there


are many different equilibria in the game. For games with only one equilibrium,


it may be difficult for a human to compute the Nash equilibrium because of


cognitive limitations. Even if human agents can compute the Nash equilibrium,


they may doubt that their opponents can perform that computation.


10


10


C. F. Camerer,


There are many behavioral models in the literature,


but one approach is to


Behavioral Game


Theory: Experiments in Strategic Inter-


combine the iterated approach from the previous section with a softmax model.


action


. Princeton University Press,


11


This


hierarchical softmax


approach (algorithm 24.9)


models the


depth of rationality


2003.


11


This


approach


is


sometimes


of an agent by a level of


. A level


agent plays its actions uniformly at


called


quantal-level-


or


logit-level-


random. A level


agent assumes the other players adopt level


strategies and


D. O. Stahl and P. W. Wilson, “Ex-


selects actions according to a softmax response with precision


. A level


agent


perimental Evidence on Players’


Models of Other Players,”


Journal


selects actions according to a softmax model of the other players playing level


of Economic Behavior & Organization


. Figure 24.1 illustrates this approach for a simple game.


vol. 25, no. 3, pp. 309–327, 1994.


We can learn the


and


parameters of this behavioral model from data. If


we have a collection of joint actions played by different agents, we can compute


the associated likelihood for a given


and


. We can then use an optimization


algorithm to attempt to find values of


and


that maximize likelihood. This


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


24.8. fictitious play


505


Algorithm 24.9. The hierarchical


struct


HierarchicalSoftmax


softmax model with precision pa-


# precision parameter


rameter


and level


. By default,


# level


it starts with an initial joint policy


# initial policy


that assigns uniform probability to


end


all individual actions.


function


HierarchicalSoftmax


::


SimpleGame


SimpleGamePolicy


ai


=>


1.0 for


ai


in


𝒜i


for


𝒜i


in


return


HierarchicalSoftmax


end


function


solve


::


HierarchicalSoftmax


for


in 1


softmax_response


for


in


end


return


end


12


J. R.


optimization typically cannot be done analytically, but we can use numerical


Wright


and


K.


Leyton-


Brown,


“Beyond


Equilibrium:


12


methods to perform this optimization.


Alternatively, we can use a Bayesian


Predicting Human Behavior in


13


approach to parameter learning.


Normal Form Games,” in