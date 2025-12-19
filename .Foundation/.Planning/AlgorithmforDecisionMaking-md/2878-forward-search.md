---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Forward Search
---

# Forward Search

_Source page: 475_



Figure


22.1.


Forward


search


searches the action-observation-


We can apply the forward search strategy from algorithm 9.2 to partially observed


belief graph to an arbitrary finite


depth in order to select the action


problems without modification. The difference between MDPs and POMDPs is


that produces the highest expected


encapsulated by one-step lookahead, which branches on actions and observations,


reward. This illustration shows a


as shown in figure 22.1. The value of taking action


from belief


can be defined


search to depth


454


chapter 22. online belief state planning


recursively to a depth