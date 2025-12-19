---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Particle Filter
---

# Particle Filter

_Source page: 412_



Discrete problems with large state spaces or continuous problems with dynamics


that are not well approximated by the linear Gaussian assumption of the Kalman


filter must often resort to approximation techniques to represent the belief and to


perform the belief update. One common approach is to use a


particle filter


, which


11


11


A tutorial on particle filters is


represents the belief state as a collection of states.


Each state in the approximate


provided by M. S. Arulampalam, S.


belief is called a


particle


Maskell, N. Gordon, and T. Clapp,


A particle filter is initialized by selecting or randomly sampling a collection


“A Tutorial on Particle Filters for


Online Nonlinear / Non-Gaussian


of particles that represent the initial belief. The belief update for a particle filter


Bayesian Tracking,”


IEEE Transac-


with


particles begins by propagating each state


by sampling from the tran-


tions on Signal Processing


, vol. 50,


no. 2, pp. 174–188, 2002.


sition distribution to obtain a new state


with probability


. The new


belief is constructed by drawing


particles from the propagated states weighted


according to the observation function


. This procedure is given


in algorithm 19.6. Example 19.4 illustrates an application of a particle filter.


In problems with discrete observations, we can also perform particle belief


updates with rejection. We repeat the following process


times to generate


the set of next state samples. First, we randomly select some state


in the filter


and then sample a next state


according to our transition model. Second, we


generate a random observation


according to our observation model. If


does


not equal the true observation


, it is rejected, and we generate a new


and


until the observations match. This


particle filter with rejection


is implemented in


algorithm 19.7.


As the number of particles in a particle filter increases, the distribution repre-


sented by the particles approaches the true posterior distribution. Unfortunately,


particle filters can fail in practice. Low particle coverage and the stochastic nature


of the resampling procedure can cause there to be no particles near the true


state. This problem of


particle deprivation


can be somewhat mitigated by several


strategies. A motivational example is given in example 19.5.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


19.6. particle filter


391


Example 19.4. A particle filter ap-


Suppose that we want to determine our position based on imperfect distance


plied to different beacon configura-


measurements to radio beacons whose locations are known. We remain


tions.


approximately still for a few steps to collect independent measurements. The


particle filter states are our potential locations. We can compare the ranges


that we would expect to measure for each particle to the observed ranges.


We assume that individual range observations from each beacon are ob-


served with zero-mean Gaussian noise. Our particle transition function adds


zero-mean Gaussian noise since we remain only approximately still.


The images here show the evolution of the particle filter. The rows cor-


respond to different numbers of beacons. The red dots indicate our true


location, and the blue dots are particles. The circles indicate the positions


consistent with noiseless distance measurements from each sensor.


Three beacons are required to identify our location accurately. A strength


of the particle filter is that it is able to represent the multimodal distributions


that are especially apparent when there are only one or two beacons.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


392


chapter 19. beliefs


Algorithm 19.6. A belief updater


struct


ParticleFilter


for particle filters, which updates


states


# vector of state samples


a vector of states representing the


end


belief based on the agent’s ac-


tion


and its observation


. Ap-


function


update


::


ParticleFilter


pendix G.5 provides an implemen-


states


rand


))


for


in


states


tation of


SetCategorical


for defin-


weights


s′


for


s′


in


states


ing distributions over discrete sets.


SetCategorical


states


weights


return


ParticleFilter


rand


length


states


)))


end


Algorithm 19.7. Updating a par-


struct


RejectionParticleFilter


ticle filter with rejection, which


states


# vector of state samples


forces sampled states to match the


end


input observation


function


update


::


RejectionParticleFilter


states


similar


states


while


length


states


rand


states


s′


rand


))


if


rand


s′


))


==


states


s′


+=


end


end


return


RejectionParticleFilter


states


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


19.6. particle filter


393


Example 19.5.


A particle filter


Spelunker Joe is lost in a grid-based maze. He lost his lantern, so he can


run for enough time can lose par-


observe his surroundings only by touch. At any given moment, Joe can tell


ticles in relevant regions of the


state space due to the stochastic na-


whether his location in the maze has walls in each cardinal direction. Joe is


ture of resampling. The problem is


fairly confident in his ability to feel walls, so he assumes that his observations


more pronounced when there are


are perfect.


fewer particles or when the parti-


cles are spread over a large state


Joe uses a particle filter to track his belief over time. At some point, he


space.


stops to rest. He continues to run his particle filter to update his belief. The


figures below show his belief over time, with dots indicating belief particles


in his particle filter corresponding to those locations in the maze.


The initial belief has one particle in each grid location that matches his


current observation of a wall to the north and south. Spelunker Joe does not


move and does not gain new information, so his belief should not change


over time. Due to the stochastic nature of resampling, subsequent beliefs may


not contain all the initial states. Over time, his belief will continue to lose


states until it only contains a single state. It is possible that this state is not


where Spelunker Joe is located.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


394


chapter 19. beliefs