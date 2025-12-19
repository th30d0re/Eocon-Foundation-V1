---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 354_



Model-based methods learn the transition and reward models through inter-


action with the environment.


Maximum likelihood models use transition counts to maintain an estimate of


the transition probabilities to successor states and to track the mean reward


associated with state-action pairs.


Maximum likelihood models must be paired with an exploration strategy, such


as those introduced in the previous chapter in the context of bandits.


Although we can replan with each step of experience, doing so exactly can be


costly.


Prioritized sweeping can focus replanning by updating the values of states


that appear to need it the most in our evolving model of the environment.


Bayesian model-based methods maintain a probability distribution over possi-


ble problems, allowing principled reasoning about exploration.


In Bayes-adaptive MDPs, their states augment the original MDP with the


probability distribution over the possible MDP models.


Posterior sampling reduces the high computational complexity of solving a


Bayes-adaptive MDP by solving an MDP sampled from the belief state rather


than reasoning about all possible MDPs.