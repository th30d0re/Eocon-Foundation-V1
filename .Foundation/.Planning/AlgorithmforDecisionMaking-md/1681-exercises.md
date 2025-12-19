---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 268_



Exercise 11.1.


If we estimate the expected discounted return of a given parameterized


policy


-dimensional vector of parameters


using


rollouts, how many


defined by an


total rollouts do we need to perform to compute the policy gradient using a finite difference


approach?


Solution:


In order to estimate the policy gradient using a finite difference approach, we


need to estimate the utility of the policy given the current parameter vector


, as well as


all


variations of the current parameter vector


for


1 :


. Since we estimate


each of these using


rollouts, we need to perform a total of


rollouts.


Exercise 11.2.


Suppose we have a robotic arm with which we are able to run experiments


manipulating a wide variety of objects. We would like to use the likelihood ratio policy


gradient or one of its extensions to train a policy that is efficient at picking up and moving


these objects. Would it be more straightforward to use a deterministic or a stochastic policy,


and why?


Solution:


The likelihood ratio policy gradient requires an explicit representation of the


transition likelihood when used with deterministic policies. Specifying an accurate explicit


transition model for a real-world robotic arm manipulation task would be challenging.


Computing the policy gradient for a stochastic policy does not require having an explicit


representation of the transition likelihood, making the use of a stochastic policy more


straightforward.


Exercise 11.3.


Consider policy gradients of the form


) =


log


Which of the following values of


result in a valid policy gradient? Explain why.


(a)


(b)


(c)


base


(d)


(e)


(f)


(g)


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


11.7. exercises


247


Solution:


results in the total discounted reward, as


(a)


and produces a valid policy gradient, as given in equation (11.19).


is the reward-to-go and produces a valid policy gradient, as given in


(b)


equation (11.26).


(c)


is the baseline subtracted reward-to-go and produces a


base


valid policy gradient, as given in equation (11.28).


(d)


is the state value function and does not produce a valid policy gradient.


(e)


is the state-action value function and produces a valid policy gradient,


as given in equation (11.27).


(f)


is the advantage function and produces a valid policy gradient, as given


in equation (11.44).


(g)


is the temporal difference residual (to be discussed


further in chapter 13) and produces a valid policy gradient because it is an unbiased


approximation of the advantage function.


Exercise 11.4.


Show that