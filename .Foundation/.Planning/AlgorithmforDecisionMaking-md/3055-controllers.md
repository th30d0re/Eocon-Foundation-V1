---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Controllers
---

# Controllers

_Source page: 493_



controller


is a policy representation that maintains its own internal state. It


Such a policy representation is


is represented as a graph consisting of a finite set of nodes


The active


node


also called a


finite state controller


changes as actions are taken and new observations are made. Having a finite set


We will refer to the controller states


of nodes makes these controllers more computationally tractable than belief-point


as ‘‘nodes’’ rather than ‘‘states’’ to


reduce ambiguity with the environ-


methods that must consider the reachable belief space.


ment state.


Actions are selected according to an


action distribution


that depends


on the current node. When selecting an action, in addition to transitioning to an


unobserved


and receiving an observation


, the control state also advances


according to a


successor distribution


. Figure 23.1 shows how these


distributions are used as a controller policy is followed. Algorithm 23.1 provides


an implementation, and example 23.1 shows a controller for the crying baby


problem.


Controllers generalize conditional plans, which were introduced in section 20.2.


Conditional plans represent policies as trees, with each node deterministically


assigning an action and each edge specifying a unique successor node. Controllers


represent policies as directed graphs, and actions may have stochastic transitions


to multiple successor nodes. Example 23.2 compares these two representations.


472


chapter 23. controller abstractions


Figure 23.1.


In a controller rep-


resentation, the action is sampled


from the action selection distribu-


tion. This action, as well as the sub-


sequent observation it produces,


are used alongside the previous


node


to produce the successor


node


Example 23.1.


A two-node con-


We can construct a simple controller for the crying baby problem (ap-


troller for the crying baby problem.


pendix F.7). This example is shown here as a graph with two nodes,


This compact representation cap-


tures a straightforward solution to


and


. When in


, the controller always ignores the baby. When in


, the


the crying baby problem (namely,


controller always feeds the baby. If the baby cries, we always transition to


to react immediately to the most


and if the baby is quiet, we always transition to


recent observation).


crying


crying


quiet


feed


) =


ignore


) =


quiet


Algorithm 23.1. A finite state con-


mutable struct


ControllerPolicy


troller policy representation for a


# problem