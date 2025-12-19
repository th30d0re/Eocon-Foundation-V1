---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 370_



Model-free methods seek to directly learn an action value function rather than


transition and reward models.


Simple techniques can be used to incrementally learn a mean from sequential


updates.


The


-learning algorithm incrementally learns an action value function using


an approximation of the Bellman equation.


In contrast with


-learning, Sarsa uses the action taken by the exploration


policy rather than maximizing over all subsequent actions in its update.


Eligibility traces can speed learning by propagating sparse rewards through


the state-action space.


-learning can be applied to approximate value functions using stochastic


gradient descent.


The catastrophic forgetting experienced by


-learning and Sarsa can be miti-


gated using experience replay, which reuses past experience tuples.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


17.8. summary


349


Algorithm 17.6.


-learning with


struct


ReplayGradientQLearning


function approximation and ex-


# action space (assumes 1:nactions)


perience replay. The update de-


# discount


pends on a parameterized policy


# parameterized action value function Q(θ,s,a)


and gradient


∇Q


∇Q


# gradient of action value function


It updates the parameter vector


# action value function parameter


# learning rate


and the circular memory buffer


buffer


# circular memory buffer


provided by


DataStructures.jl


# number of steps between gradient updates


It updates


every


steps using


m_grad


# batch size


a gradient estimated from


m_grad


end


samples from the buffer.


function


lookahead


model


::


ReplayGradientQLearning


return


model


model


end


function


update!


model


::


ReplayGradientQLearning


s′


model


model


model


model


model


buffer


m_grad


model


buffer


model


model


m_grad


if


isfull


buffer


maximum


for


in


∇Q


s′


s′


))


model


∇Q


mean


∇Q


s′


for


s′


in


rand


buffer


m_grad


))


+=


scale_gradient


for


in 1


# discard oldest experiences


popfirst!


buffer


end


else


push!


buffer


, (


s′


))


end


return


model


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


350


chapter 17. model-free methods


Example 17.4. An application of ex-


Suppose we want to add experience replay to example 17.3. When construct-


perience replay to the simple regu-


ing the model, we need to provide a replay buffer with the desired capacity:


lator problem with


-learning and


action value approximation.


capacity


100


# maximum size of the replay buffer


ExperienceTuple


Tuple


Float64


Float64


Float64


Float64


CircularBuffer


ExperienceTuple


}(


capacity


# replay buffer


m_grad


20


# batch size


model


ReplayGradientQLearning


∇Q


m_grad


We can vary the number of steps between gradient updates


and the


depth of each simulation


. In the plot shown here, we limit all training runs


to


md


30


experience tuples with each iteration. It indicates that rollouts to


a sufficient depth are necessary for training to succeed. In addition, very few


rollouts to an excessive depth do not perform as well as a moderate number


of rollouts to a moderate depth.


30


15


10


20


10


40


60


expected value


80


100


20


60


80


40


100


iteration


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


17.9. exercises


351