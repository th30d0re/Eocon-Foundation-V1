---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Heuristic Search
---

# Heuristic Search

_Source page: 219_



Time Dynamic Programming,”


Ar-


tificial Intelligence


, vol. 72, no. 1–2,


pp. 81–138, 1995. Other forms of


Heuristic search


(algorithm 9.8) uses


simulations of a greedy policy with respect


heuristic search are discussed by


to a value function


from the current state


The value function


is initialized


Mausam and A. Kolobov,


Planning


with Markov Decision Processes: An


to an upper bound of the value function


, which is referred to as a


heuristic


. As


AI Perspective


. Morgan & Claypool,


we run these simulations, we update our estimate of


through lookahead. After


2012.


running these simulations, we simply select the greedy action from


with respect


to


. Figure 9.5 shows how


and the greedy policy changes with the number of


simulations.


Heuristic search is guaranteed to converge to the optimal utility function so long


Such a heuristic is referred to as


as the heuristic


is indeed an upper bound on the value function.


The efficiency


an


admissible heuristic


of the search depends on the tightness of the upper bound. Unfortunately, tight


bounds can be difficult to obtain in practice. While a heuristic that is not a true


upper bound may not converge to the optimal policy, it may still converge to a


policy that performs well. The time complexity is