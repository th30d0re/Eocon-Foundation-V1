---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Decision Networks
---

# Decision Networks

_Source page: 138_



proach


, 4th ed. Pearson, 2021.


decision network


, sometimes called an


influence diagram


, is a generalization of a


Bayesian network to include action and utility nodes so that we may compactly


10


10


An extensive discussion of de-


represent the probability and utility models defining a decision problem.


The


cision networks can be found


state, action, and observation spaces in the previous section may be factored, and


in F. V. Jensen and T. D. Nielsen,


the structure of a decision network captures the relationships between the various


Bayesian Networks and Decision


Graphs


, 2nd ed. Springer, 2007.


components.


Decision networks are composed of three types of nodes:


• A


chance node


corresponds to a random variable (indicated by a circle).


• An


action node


corresponds to a decision variable (indicated by a square).


utility node


corresponds to a utility variable (indicated by a diamond) and


cannot have children.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


6.5. decision networks


117


Example 6.3. Applying the princi-


Suppose that we are trying to decide whether to bring an umbrella on our


ple of maximum expected utility to


vacation given the weather forecast for our destination. We observe the


the simple decision of whether to


bring an umbrella.


forecast


, which may be either rain or sun. Our action


is either to bring


our umbrella or leave our umbrella. The resulting state


is a combination of


whether we brought our umbrella and whether there is sun or rain at our


destination. Our probabilistic model is as follows:


forecast rain


bring umbrella


rain with umbrella


0.9


forecast rain


leave umbrella


rain without umbrella


0.9


forecast rain


bring umbrella


sun with umbrella


0.1


forecast rain


leave umbrella


sun without umbrella


0.1


forecast sun


bring umbrella


rain with umbrella


0.2


forecast sun


leave umbrella


rain without umbrella


0.2


forecast sun


bring umbrella


sun with umbrella


0.8


forecast sun


leave umbrella


sun without umbrella


0.8


As shown in the table, we assume that our forecast is imperfect; rain


forecasts are right