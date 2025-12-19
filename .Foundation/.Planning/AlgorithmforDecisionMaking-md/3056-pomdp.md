---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 494_



. The nodes in


are an ab-


# set of controller nodes


stract representation of reachable


# action selection distribution


beliefs. Actions and controller suc-


# successor selection distribution


cessor nodes are selected stochasti-


end


cally. Given a node


, actions are se-


function


::


ControllerPolicy


)(


lected following the distribution


The function


implements this


dist


for


in


mechanism to stochastically select


return


rand


SetCategorical


dist


))


actions. After performing action


end


in node


and observing observa-


tion


, the successor is selected fol-


function


update


::


ControllerPolicy


lowing the distribution


. The func-


tion


update


implements this mech-


dist


x′


for


x′


in


anism to stochastically select suc-


return


rand


SetCategorical


dist


))


cessor nodes.


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


23.1. controllers


473


Example 23.2. A comparison of a


Consider a three-step conditional plan (left) compared with the more general,


simple conditional plan with a sim-


two-node finite state controller (right). In this case, actions and successors are


ple deterministic controller.


selected deterministically. The deterministic action is marked in the center of


a node, and the outgoing edges represent the deterministic successor nodes.


This problem has two actions (


and


) and two observations (


and


).


quiet


crying


ignore


feed


The conditional plan performs action


first, toggles the previously cho-


sen action if it observes


, and preserves the previously chosen action if it


observes


. The controller performs the same logic, with five fewer controller


nodes. Moreover, the controller represents the described infinite horizon pol-


icy perfectly with only two nodes (compared to seven). The conditional plan


cannot capture this infinite horizon policy because it would require a tree of


infinite depth.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


474


chapter 23. controller abstractions


Controllers have several advantages over conditional plans. First, controllers


can provide a more compact representation. The number of nodes in a conditional


plan grows exponentially with depth, but this need not be the case with finite state


controllers. The approximation methods from previous chapters might also not


be as efficient because they must maintain a large set of beliefs and corresponding


alpha vectors. Controllers can be much more compact, considering infinitely


many possible reachable beliefs with a small, finite number of nodes. Another


advantage of controllers is that they do not require that a belief be maintained.


Each controller node corresponds to a subset of the belief space. These subsets are


not necessarily mutually exclusive. A controller transitions between these subsets


that together cover the reachable belief space. The controller itself selects a new


node based on each observation rather than relying on a belief update, which can


be expensive for some domains.


The utility of following a controller policy can be computed by forming a


product MDP whose state space is