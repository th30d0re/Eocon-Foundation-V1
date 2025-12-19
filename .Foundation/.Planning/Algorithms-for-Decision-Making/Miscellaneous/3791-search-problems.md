---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Search Problems
---

# Search Problems

_Source page: 621_



In a search problem, we choose action


based on observing state


at time


and then receive a reward


. The


action space


is the set of possible actions,


and the


state space


is the set of possible states. Some of the algorithms assume


that these sets are finite, but this is not required in general. The state evolves


deterministically and depends only on the current state and action taken. We


use


to denote the set of valid actions from state


. When there are no valid


actions, the state is considered to be


absorbing


and yields zero reward for all future


time steps. Goal states, for example, are typically absorbing.


The deterministic state transition function


gives the successor state


The reward function


gives the reward received when executing action


from state


. Search problems typically do not include a discount factor


that


penalizes future rewards. The objective is to choose a sequence of actions that


maximizes the sum of rewards, or


return


. Algorithm E.1 provides a data structure


for representing search problems.


600


appendix e. search algorithms


Algorithm E.1. The search problem


struct


Search


data structure.


# state space


# valid action function


# transition function


# reward function


end