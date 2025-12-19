---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 172_



Discrete MDPs with bounded rewards can be solved exactly through dynamic


programming.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


7.10. exercises


151


Algorithm 7.11.


A method that


struct


LinearQuadraticProblem


computes an optimal policy for


Ts


# transition matrix with respect to state


an


h_max


-step horizon MDP with


Ta


# transition matrix with respect to action


stochastic linear dynamics param-


Rs


# reward matrix with respect to state (negative semidefinite)


eterized by matrices


Ts


and


Ta


and


Ra


# reward matrix with respect to action (negative definite)


quadratic reward parameterized


h_max


# horizon


end


by matrices


Rs


and


Ra


. The method


returns a vector of policies where


function


solve


::


LinearQuadraticProblem


entry


produces the optimal first


Ts


Ta


Rs


Ra


h_max


Ts


Ta


Rs


Ra


h_max


action in an


-step policy.


zeros


size


Rs


))


πs


Any


->


zeros


size


Ta


))]


for


in 2


h_max


Ts


'*


Ta


((


Ta


'*


Ta


Ra


Ta


'*


))


Ts


Rs


= -


Ta


'*


Ta


Ra


Ta


' *


Ts


push!


πs


->


end


return


πs


end


Policy evaluation for such problems can be done exactly through matrix inver-


sion or can be approximated by an iterative algorithm.


Policy iteration can be used to solve for optimal policies by iterating between


policy evaluation and policy improvement.


Value iteration and asynchronous value iteration save computation by directly


iterating the value function.


The problem of finding an optimal policy can be framed as a linear program


and solved in polynomial time.


• Continuous problems with linear transition functions and quadratic rewards


can be solved exactly.