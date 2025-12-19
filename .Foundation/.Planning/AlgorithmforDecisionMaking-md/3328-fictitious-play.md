---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Fictitious Play
---

# Fictitious Play

_Source page: 543_



Mathematical Programming


, vol. 50,


no. 1–3, pp. 227–237, 1991.


As we did in the context of simple games, we can take a learning-based approach to


arrive at joint policies by running agents in simulation. Algorithm 25.6 generalizes


the simulation loop introduced in the previous chapter to handle state transitions.


The various policies run in simulation update themselves based on the state


transitions and the actions taken by the various agents.


One approach for updating policies is to use a generalization of


fictitious


W. Uther and M. Veloso, “Adver-


play


(algorithm 25.7) from the previous chapter,


which involves maintaining


sarial Reinforcement Learning,”


a maximum-likelihood model over the policies of the other agents. The maxi-


Carnegie Mellon University, Tech.


mum likelihood model tracks the state in addition to the action being taken by


Rep. CMU-CS-03-107, 1997. M.


Bowling and M. Veloso, “An Anal-


each agent. We track the number of times that agent


takes action


in state


ysis of Stochastic Game Theory for


storing it in table


, typically initialized to


. Then, we can compute the


Multiagent Reinforcement Learn-


ing,” Carnegie Mellon University,


best response, assuming that each agent


follows the state-dependent stochastic


Tech. Rep. CMU-CS-00-165, 2000.


policy: