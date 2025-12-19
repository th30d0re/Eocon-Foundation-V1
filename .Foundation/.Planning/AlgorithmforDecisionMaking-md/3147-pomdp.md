---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 510_



of the controller gradient ascent


method. It constructs the gradients


x1


of the utility


with respect to the


length


),


length


),


length


policy gradients


∂U′∂ψ


and


∂U′∂η


X𝒮


vec


collect


product


)))


T′


sum


s′


sum


s′


x′


for


in


for


in


for


in


X𝒮


, (


x′


s′


in


X𝒮


R′


sum


for


in


for


in


X𝒮


1.0


length


X𝒮


))


T′


invZ


inv


∂Z∂ψ


hx


ha


==


hx


ha


s′


sum


ha


s′


hx


ha


x′


for


in


))


0.0


for


in


X𝒮


, (


x′


s′


in


X𝒮


∂Z∂η


hx


ha


ho


hx′


==


hx


&&


x′


==


hx′


hx


ha


ha


s′


ha


s′


ho


))


0.0


for


in


X𝒮


, (


x′


s′


in


X𝒮


∂R′∂ψ


hx


ha


==


hx


ha


0.0 for


in


X𝒮


∂R′∂η


hx


ha


ho


hx′


0.0 for


in


X𝒮


∂U′∂ψ


hx


ha


invZ


∂R′∂ψ


hx


ha


∂Z∂ψ


hx


ha


invZ


R′


∂U′∂η


hx


ha


ho


hx′


invZ


∂R′∂η


hx


ha


ho


hx′


∂Z∂η


hx


ha


ho


hx′


invZ


R′


return


∂U′∂ψ


∂U′∂η


end


During execution, controllers will never divide by zero in the way that belief-based


policies can. Belief-based methods require maintaining a belief. The discrete state filter


from equation (19.7) will divide by zero if an impossible observation is made. This can


happen when a noisy observation from a sensor returns an observation that the models of


and


does not accurately capture.


Exercise 23.2.


Controller policy iteration only adds nodes with deterministic action selec-


tion functions and successor distributions. Does this mean that the resulting controller is


necessarily suboptimal?


Solution:


Controller policy iteration is guaranteed to converge on an optimal policy in


the limit. However, the method cannot find more compact representations of optimal


controller policies that may require stochastic nodes.


Exercise 23.3.


Prove that node pruning in policy iteration does not affect the utility.


Solution:


Let


be the new node from some iteration


, and


be a previous node from


iteration


By construction,


defines all new nodes


to only have a successor


from


the previous iteration. Thus, for each state


only sums over the successors


in equation (23.1). This means that the other utilities in iteration


, including


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


23.6. exercises


489


Example 23.6. A demonstration of


Consider the catch problem (appendix F.9) with a uniform initial belief


the controller gradient algorithm


The diagrams here show the utility of the policy over gradient ascent iteration


for controllers with a fixed size of


. The policy is shown to re-


applied to the catch problem with


nodes. The left node is


fine itself over the algorithm’s it-


At iteration


, the policy is essentially random, both in action selection


erations. The agent incrementally


and successor selection:


determines how to best use its fixed


number of nodes, resulting in a


reasonable and interpretable pol-


catch, drop


drop


catch, drop


drop


icy on convergence. The stochas-


catch, drop


catch, drop


tic controllers are shown as circles,


with the most likely action in the


middle. The outgoing edges show


10


10


60


successor node selections given an


observation. The stochasticity in


catch, drop


catch, drop


node actions and successors are


shown as opacity (more opaque is


higher probability, more transpar-


At iteration


50


, the agent has determined a reasonable distance to throw


ent is lower probability).


the ball (


50


) but still has not used its three nodes to remember anything


useful:


catch, drop


drop


catch, drop


catch, drop


catch, drop


catch, drop


50


50


50


catch, drop


catch, drop


catch, drop


At iteration


500


, the policy has constructed a reasonable plan, given its


fixed three nodes of memory:


catch, drop


catch, drop


catch


drop


drop


50


50


40


catch


catch


It first tries throwing the ball at a distance of


40


. If the child catches the


ball, then it increases the range to


50


. It uses the final node to remember how


many times the child caught the ball (up to twice) to choose the distance.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


490


chapter 23. controller abstractions


a self-loop to


itself, do not affect the utility


. Since the initial node is chosen by


equation (23.3), we must ensure that the utility with and without the pruned node at all


beliefs is the same. A node is pruned in one of two ways.


First,


obtains a higher utility over all states than its pruned successor


. Formally,


for all


. The pruning step replaces


with


, including


, and


. By construction,


has not decreased at any state


Second,


is identical to an existing previous node


. Note that this means the transition


) =


. This means that the utility is identical except that


is reduced


by


; in other words,


) =


by equation (23.1). Pruning


does not


affect the final utility.


Exercise 23.4.


Devise an algorithm that uses the nonlinear program algorithm to find the


minimum fixed-sized controller required to obtain the optimality of a large fixed-sized


controller of size


. You can assume that the nonlinear optimizer returns the optimal policy


in this case.


Solution:


The idea is to create an outer loop that increments the fixed size of the controller,


after knowing the utility of the large fixed-sized controller. First, we must compute the


large fixed-sized controller’s utility


at initial node


and initial


belief


. Next, we create a loop that increments the size


of the controller. At each step, we


evaluate the policy and compute the utility


. By our assumption, the returned controller


produces a globally optimal utility for the fixed size


. Once we arrive at a utility


, if we


see that


, then we stop and return the policy.


Exercise 23.5.


Analyze the controller gradient ascent algorithm’s gradient step. Assume


that


|S|


is larger than


|A|


and


|O|


. What is the most computationally expensive part of the


gradient step? How might this be improved?


F. L. Gall, “Powers of Tensors and


Solution:


Computing the inverse


= (


is the most computationally expensive


Fast Matrix Multiplication,” in


In-


part of the gradient step, as well as the entire gradient algorithm. The matrix


is of size


ternational Symposium on Symbolic