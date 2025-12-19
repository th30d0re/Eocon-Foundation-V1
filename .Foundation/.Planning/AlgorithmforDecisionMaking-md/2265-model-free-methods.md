---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Model-Free Methods
---

# Model-Free Methods

_Source page: 357_



Many of the topics in this chap-


In contrast with model-based methods,


model-free reinforcement learning


does not


ter are covered in greater depth by


require building explicit representations of the transition and reward models.


R. S. Sutton and A. G. Barto,


Rein-


The model-free methods discussed in this chapter model the action value func-


forcement Learning: An Introduction


2nd ed. MIT Press, 2018. See also


tion directly. Avoiding explicit representations is attractive, especially when the


D. P. Bertsekas,


Reinforcement Learn-


problem is high dimensional. This chapter begins by introducing incremental


ing and Optimal Control


. Athena Sci-


entific, 2019.


estimation of the mean of a distribution, which plays an important role in estimat-


ing the mean of returns. We then discuss some common model-free algorithms


and methods for handling delayed reward more efficiently. Finally, we discuss


Although this part of the book has


how to use function approximation to generalize from our experience.


been focusing on problems where


the model of the environment is


unknown, reinforcement learning