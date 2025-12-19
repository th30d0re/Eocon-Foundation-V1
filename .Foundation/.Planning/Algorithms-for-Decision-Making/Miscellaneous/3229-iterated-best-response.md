---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Iterated Best Response
---

# Iterated Best Response

_Source page: 525_



Iterated best response will con-


Because computing a Nash equilibrium can be computationally expensive, an


verge, for example, for a class


alternative approach is to iteratively apply best responses in a series of repeated


known as


potential games


, as dis-


games. In


iterated best response


(algorithm 24.8), we randomly cycle between


cussed in Theorem 19.12 of the text-


book by N. Nisan, T. Roughgar-


agents, solving for each agent’s best response policy in turn. This process may


den, É. Tardos, and V. V. Vazirani,


converge to a Nash equilibrium, but there are guarantees only for certain classes


eds.,


Algorithmic Game Theory


. Cam-


bridge University Press, 2007.


of games.


In many problems, it is common to observe cycles.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


504


chapter 24. multiagent reasoning


Algorithm 24.8. Iterated best re-


struct


IteratedBestResponse


sponse involves cycling through


k_max


# number of iterations


the agents and applying their best


# initial policy


response to the other agents. The


end


algorithm starts with some initial


policy and stops after


k_max


iter-


function


IteratedBestResponse


::


SimpleGame


k_max


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


ations. For convenience, we have


return


IteratedBestResponse


k_max


a constructor that takes as input a


end


simple game and creates an initial


policy that has each agent select


function


solve


::


IteratedBestResponse


actions uniformly at random. The


same solve function will be reused


for


in 1


k_max


in the next chapter in the context of


best_response


for


in


more complicated forms of games.


end


return


end