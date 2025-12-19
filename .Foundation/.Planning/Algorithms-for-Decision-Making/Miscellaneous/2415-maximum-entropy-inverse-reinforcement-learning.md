---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Maximum Entropy Inverse Reinforcement Learning
---

# Maximum Entropy Inverse Reinforcement Learning

_Source page: 387_



The inverse reinforcement learning approach from the previous section is under-


specified, meaning that there are often multiple policies that can produce the


same feature expectations as the expert demonstrations. This section introduces


maximum entropy inverse reinforcement learning


, which avoids this ambiguity by


B. D. Ziebart, A. Maas, J. A. Bag-


preferring the policy that results in the distribution over trajectories that has


nell, and A. K. Dey, “Maximum En-


maximum


entropy


(appendix A.8).


The problem can be transformed into one of


tropy Inverse Reinforcement Learn-


finding the best reward function parameters


in a maximum likelihood estima-


ing,” in


AAAI Conference on Artifi-


cial Intelligence (AAAI)


, 2008.


tion problem, given the expert data


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


366


chapter 18. imitation learning


Figure 18.2. A geometric visual-


ization of three example iterations


of the maximum-margin inverse


reinforcement learning algorithm,


going top to bottom. In each itera-


tion, the new weight vector points


in the direction perpendicular to


the hyperplane that separates the


expert feature expectation vector


from that of the previous policy


with the largest possible margin.


The margin decreases with each it-


eration.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


18.5. maximum entropy inverse reinforcement learning


367


Algorithm 18.5.


Maximum mar-


function


calc_weighting


::


InverseReinforcementLearning


μs


gin inverse reinforcement learning,


μE


μE


which computes a mixed policy


length


μE


whose feature expectations match


model


Model


Ipopt


Optimizer


those of given expert demonstra-


@variable


model


tions. We use


JuMP.jl


to solve con-


@variable


model


strained optimization problems.


@objective


model


Max


for


in


μs


This implementation requires that


@constraint


model


ϕ⋅μE


ϕ⋅μ


the provided reinforcement learn-


end


ing struct has a weight vector


that


@constraint


model


ϕ⋅ϕ


can be updated with new values.


optimize!


model


The method returns the stochas-


return


value


),


value.


))


tic weightings


and parameteriza-


end


tions


θs


for the component policies.


function


calc_policy_mixture


::


InverseReinforcementLearning


μs


μE


μE


length


μs


model


Model


Ipopt


Optimizer


@variable


model


@objective


model


Min


, (


μE


sum


μs


for


in 1


))


μE


sum


μs


for


in 1


)))


@constraint


model


sum


==


optimize!


model


return


value.


end


function


optimize


::


InverseReinforcementLearning


RL


RL


θs


μs


feature_expectations


->


))]


while true


calc_weighting


μs


if


break


end


copyto!


RL


# R(s,a) = ϕ⋅β(s,a)


optimize


RL


push!


θs


push!


μs


feature_expectations


->


)))


end


calc_policy_mixture


μs


return


θs


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


368


chapter 18. imitation learning


10


For simplicity, this section as-


sumes a finite horizon and that the


10


Any policy


induces a distribution over trajectories


. Different policies


state and action spaces are discrete,


produce different trajectory distributions. We are free to choose any of these


making


a probability mass.


To extend maximum entropy in-


distributions over trajectories that match the expert feature expectations. The


verse reinforcement learning both


principle of maximum entropy


chooses the least informative distribution, which


to problems with continuous state


11


and action spaces where the dy-


corresponds to the one with maximum entropy.


It can be shown that the least


namics may be unknown, consider


informative trajectory distribution takes the following form:


guided cost learning. C. Finn, S.


Levine, and P. Abbeel, “Guided


Cost Learning: Deep Inverse Op-