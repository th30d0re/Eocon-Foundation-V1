---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Trade Analysis
---

# Trade Analysis

_Source page: 311_



Many interesting tasks involve multiple, often competing, objectives. For au-


tonomous systems, there is often a trade-off between safety and efficiency. In


designing a collision avoidance system, we want to be very safe without making


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


290


chapter 14. policy validation


Example 14.4. Probability of a col-


We can plot collision probability when starting from different initial states,


lision when following the optimal


similar to example 14.2. Here, we use a policy optimized for the parameters


collision avoidance policies when


there is a mismatch between the


in appendix F.6, but we vary the limit


limit


in the evaluation model.


model used for planning and the


model used for evaluation.


0.0 m/s


5.0 m/s


200


0.8


100


m/s


0.6