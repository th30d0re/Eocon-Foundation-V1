---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Gap Heuristic Search
---

# Gap Heuristic Search

_Source page: 482_



Similar to the offline heuristic search presented in section 21.8,


gap heuristic search


uses the gap between the upper and lower bounds to guide our search toward


beliefs that have uncertainty in their associated value and as an indication of


when we can stop exploring. The gap at a belief


is the difference between the


upper-bound and lower-bound values:


. Search algorithms with the


gap heuristic select the observation that maximizes the gap because they are more


likely to benefit from a belief backup. Actions are often selected according to a


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


22.7. gap heuristic search


461


Example


22.5.


Determinized


Suppose that we generate a determinizing matrix


for a


-state


sparse tree search uses a matrix to


-observation problem with four histories up to depth


make tree traversal deterministic


for a given particle.