---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Policy Iteration
---

# Policy Iteration

_Source page: 162_



Policy iteration


(algorithm 7.6) is one way to compute an optimal policy. It involves


iterating between policy evaluation (section 7.2) and policy improvement through


a greedy policy (algorithm 7.5). Policy iteration is guaranteed to converge given


any initial policy. It converges in a finite number of iterations because there are


finitely many policies and every iteration improves the policy if it can be improved.


Although the number of possible policies is exponential in the number of states,


policy iteration often converges quickly. Figure 7.5 demonstrates policy iteration


on the hex world problem.


Algorithm 7.6.


Policy iteration,


struct


PolicyIteration


which iteratively improves an ini-


# initial policy


tial policy


to obtain an optimal


k_max


# maximum number of iterations


policy for an MDP


with discrete


end


state and action spaces.


function


solve


::


PolicyIteration


::


MDP


for


k_max


policy_evaluation


π′


ValueFunctionPolicy


if


all


==


π′


for


in


break


end


π′


end


return


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


7.5. value iteration


141


Figure 7.5. Policy iteration used to


iteration 1


iteration 2


iteratively improve an initially east-


moving policy in the hex world


problem to obtain an optimal pol-


icy. In the first iteration, we see the


value function associated with the


east-moving policy and arrows in-


iteration 3


iteration 4


dicating the policy that is greedy


with respect to that value function.


Policy iteration converges in four


iterations; if we ran for a fifth or


more iterations, we would get the


same policy.


Policy iteration tends to be expensive because we must evaluate the policy


M. L. Puterman and M. C. Shin,


in each iteration. A variation of policy iteration called


modified policy iteration


“Modified Policy Iteration Algo-


approximates the value function using iterative policy evaluation instead of exact


rithms for Discounted Markov De-


policy evaluation. We can choose the number of policy evaluation iterations


cision Problems,”


Management Sci-


ence


, vol. 24, no. 11, pp. 1127–1137,


between steps of policy improvement. If we use only one iteration between steps,


1978.


then this approach is identical to value iteration.