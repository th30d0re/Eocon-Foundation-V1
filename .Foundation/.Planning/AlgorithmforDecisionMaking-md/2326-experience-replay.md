---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Experience Replay
---

# Experience Replay

_Source page: 367_



and M. Riedmiller, “Playing Atari


with Deep Reinforcement Learn-


A major challenge of using global function approximation with reinforcement


ing,” 2013. arXiv: 1312 . 5602v1


learning is


catastrophic forgetting


. For example, we might initially discover that


. This concept was explored ear-


lier by L.


J. Lin, “Reinforcement


our particular policy brings us to a low-reward region of the state space. We then


Learning for Robots Using Neu-


refine our policy to avoid that area. However, after some amount of time, we may


ral Networks,” Ph.D. dissertation,


Carnegie Mellon University, 1993.


forget why it was important to avoid that region of the state space, and we may


15


Variations of this approach in-


risk reverting to a poorly performing policy.


clude prioritizing experiences. T.


14


Catastrophic forgetting can be mitigated with


experience replay


where a fixed


Schaul, J. Quan, I. Antonoglou, and


number of the most recent experience tuples are stored across training iterations.


D. Silver, “Prioritized Experience


Replay,” in


International Conference


batch


of tuples are sampled uniformly from this


replay memory


to remind us to


on Learning Representations (ICLR)


15


avoid strategies that we have already discovered are poor.


The update equation


2016.


from equation (17.21) is modified to become


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


346


chapter 17. model-free methods


Example 17.3. How to use an ex-


We are interested in applying


-learning with a linear action value approx-


ploration strategy with


-learning


imation to the simple regulator problem with


. Our action value ap-


with action value function approx-


imation in simulation. The param-


proximation is