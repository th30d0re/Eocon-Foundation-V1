---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 143_



EU


for all


, in which case equation (6.9) evaluates to


. For example, if the


optimal decision is to treat the disease regardless of the outcome of the


diagnostic


test


, then the value of observing the outcome of the test is


The value of information only captures the increase in expected utility from


making an observation. A cost may be associated with making a particular obser-


vation. Some diagnostic tests may be inexpensive, such as a temperature reading;


other diagnostic tests are more costly and invasive, such as a lumbar puncture.


The value of information obtained by a lumbar puncture may be much greater


than that of a temperature reading, but the costs of the tests should be taken into


consideration.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


122


chapter 6. simple decisions


Value of information is an important and often-used metric for choosing what


to observe. Sometimes the value of information metric is used to determine an


appropriate sequence of observations. After each observation, the value of infor-


mation is determined for the remaining unobserved variables. The unobserved


variable with the greatest value of information is then selected for observation. If


there are costs associated with making different observations, then these costs are


subtracted from the value of information when determining which variable to


observe. The process continues until it is no longer beneficial to observe any more


variables. The optimal action is then chosen. This greedy selection of observations


is only a heuristic; it may not represent the truly optimal sequence of observations.


The optimal selection of observations can be determined by using the techniques


for sequential decision making introduced in later chapters.