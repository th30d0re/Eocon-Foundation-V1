---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Particle Injection
---

# Particle Injection

_Source page: 416_



Particle injection


involves injecting random particles to protect against particle


deprivation. Algorithm 19.8 injects a fixed number of particles from a broader


12


For robotic localization problems,


12


distribution, such as a uniform distribution over the state space.


While particle


it is a common practice to inject


particles from a uniform distribu-


injection can help prevent particle deprivation, it also reduces the accuracy of the


tion over all possible robot poses,


posterior belief represented by the particle filter.


weighted by the current observa-


tion.


Algorithm 19.8.


Particle filter


struct


InjectionParticleFilter


update with injection, in which


states


# vector of state samples


m_inject


particles are sampled


m_inject


# number of samples to inject


from the injection distribution


D_inject


# injection distribution


D_inject


to reduce the risk of par-


end


ticle deprivation.


function


update


::


InjectionParticleFilter


m_inject


D_inject


m_inject


D_inject


states


rand


))


for


in


states


weights


s′


for


s′


in


states


SetCategorical


states


weights


length


states


states


vcat


rand


m_inject


),


rand


D_inject


m_inject


))


return


InjectionParticleFilter


states


m_inject


D_inject


end


Instead of using a fixed number of injected particles at each update, we can


take a more adaptive approach. When the particles are all being given very low


weights, we generally want to inject more particles. It might be tempting to choose


the number of injected particles based solely on the mean weight of the current


set of particles. However, doing so can make the success of the filter sensitive to


naturally low observation probabilities in the early periods when the filter is still


13


13


S. Thrun, W. Burgard, and D. Fox,


converging or in moments of high sensor noise.


Probabilistic Robotics


. MIT Press,


Algorithm 19.9 presents an


adaptive injection


algorithm that keeps track of two


2006.


exponential moving averages of the mean particle weight and bases the number


14


14


D. E. Goldberg and J. Richard-


of injections on their ratio.


If


mean


is the current mean particle weight, the two


son, “An Experimental Compari-


moving averages are updated according to


son of Localization Methods,” in


International Conference on Genetic