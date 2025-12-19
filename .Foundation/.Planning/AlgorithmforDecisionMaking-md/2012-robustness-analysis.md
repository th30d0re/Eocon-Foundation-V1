---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Robustness Analysis
---

# Robustness Analysis

_Source page: 310_



importance sampling


direct sampling


Before deploying a system in the real world, it is important to study its robustness


Figure 14.3. Collision probability


to modeling errors. We can use the tools mentioned in the previous sections,


when following the optimal policy


such as policy evaluation and importance sampling, but evaluate our policies on


as estimated by importance sam-


pling and direct sampling.


environments that deviate from the model assumed when optimizing the policy.


Figure 14.4 shows how performance varies as the true model deviates from the


one used for optimization. We can also study the sensitivity of our metrics to


modeling assumptions over the state space (example 14.4). If performance on


the relevant metrics appears to be preserved under plausible perturbations of the


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


14.4. trade analysis


289


environment model, then we can have greater confidence that our system will


behave as planned when deployed.


10


We typically want our


planning model


, the model we use for optimizing our


10


policies, to be relatively simple to prevent overfitting to potentially erroneous


10


modeling assumptions that are not representative of the real world. A side benefit


of simpler planning models is that they can make planning more computation-


10


Collision probability


ally efficient. However, our


evaluation model


can be as complex as we can justify.


0.5


1.5


For example, we may use a simple, low-dimensional, discrete model of aircraft


m/s


limit


dynamics when generating a collision avoidance policy, but then evaluate that


Figure 14.4. Analysis of robustness


policy in a continuous, high-fidelity simulation. A simpler planning model is


of a policy optimized for


limit


often more robust to perturbations in the evaluation model.


1 m/s


but evaluated in environ-


ments with different values for


The process of evaluating our policies on a variety of evaluation models is


limit


sometimes referred to as


stress testing


, especially if the spectrum of evaluation


models includes fairly extreme scenarios. In collision avoidance, extreme scenarios


might include those where the aircraft are converging on each other with extreme


climb rates that may not be physically achievable. Understanding what categories


of scenarios can lead to system failure can be useful during the design phase,


even if we choose not to optimize the behavior of the system for these scenarios


because they are deemed unrealistic.


If we find that our policies are overly sensitive to our modeling assumptions, we


G. N. Iyengar, “Robust Dynamic


may consider using a method known as


robust dynamic programming


Instead of


Programming,”


Mathematics of Op-


committing to a particular transition model, we have a suite of transition models


erations Research


, vol. 30, no. 2,


. We can revise the Bellman update equation from


1:


and reward models


1:


pp. 257–280, 2005. This approach


can improve robustness in the con-


equation (7.16) to provide robustness to different models as follows:


text of collision avoidance. M. J.


Kochenderfer, J. P. Chryssantha-


copoulos, and P. Radecki, “Robust-