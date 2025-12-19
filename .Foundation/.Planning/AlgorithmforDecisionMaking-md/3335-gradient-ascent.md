---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Gradient Ascent
---

# Gradient Ascent

_Source page: 548_



We can use


gradient ascent


(algorithm 25.8) to learn policies in a way similar to


what was done in the previous chapter for simple games. The state must now be


considered and requires learning the action value function. At each time step


all agents perform joint actions


. As in gradient ascent for simple


in a state


games, an agent


assumes that the agents’ policies


are the observed actions


. The gradient is