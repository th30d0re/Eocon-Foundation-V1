---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Eligibility Traces
---

# Eligibility Traces

_Source page: 363_



One of the disadvantages of


-learning and Sarsa is that learning can be very


slow, especially with


sparse rewards


. For example, suppose that the environment


has a single goal state that provides a large reward, and the reward is zero at


all other states. After an amount of random exploration in the environment, we


reach the goal state. Regardless of whether we use


-learning or Sarsa, we only


update the action value of the state immediately preceding the goal state. The


values at all other states leading up to the goal remain at zero. A large amount of


exploration is required to slowly propagate nonzero values to the remainder of


the state space.


-learning and Sarsa can be modified to propagate reward backward to the


Eligibility traces were proposed


states and actions leading to the source of the reward using


eligibility traces


The


in the context of temporal differ-


credit is decayed exponentially so that states closer to the reward are assigned


ence learning by R. Sutton, “Learn-


larger values. It is common to use


as the exponential decay parameter.


ing to Predict by the Methods


of Temporal Differences,”


Machine


Versions of


-learning and Sarsa with eligibility traces are often called Q


and


Learning


, vol. 3, no. 1, pp. 9–44,


Sarsa


1988.


These


A version of Sarsa(


) is implemented in algorithm 17.4, which maintains an


algorithms


were


in-


troduced by C. J. C. H. Watkins,


exponentially decaying visit count


for all state-action pairs. When action


“Learning from Delayed Rewards,”


is taken in state


is incremented by


. The Sarsa temporal difference up-


Ph.D. dissertation, University of


Cambridge, 1989. and J. Peng


date is then partially applied to every state-action pair according to this decaying


and R. J. Williams, “Incremental


visit count.


Multi-Step Q-Learning,”


Machine


Let


denote the Sarsa temporal difference update:


Learning


, vol. 22, no. 1–3, pp. 283–


290, 1996.