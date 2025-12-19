---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: (AISTATS)
---

# (AISTATS)

_Source page: 380_



, vol. 15, 2011.


These interactive demonstrations iteratively build a data set covering the re-


gions of the state space that the agent is likely to encounter, based on previous


learning iterations. With each iteration, newly added examples compose a smaller


fraction of the data set, thereby leading to smaller policy changes. While sequen-


tial interactive demonstration can work well in practice, it is not guaranteed to


converge. It can be shown that mixing in influence from the expert policy can


guarantee convergence, which is the subject of the next section.


S. Ross and J. A. Bagnell, “Ef-