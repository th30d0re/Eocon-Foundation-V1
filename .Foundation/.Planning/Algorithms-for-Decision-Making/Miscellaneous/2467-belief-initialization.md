---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Belief Initialization
---

# Belief Initialization

_Source page: 401_



There are different ways to represent our beliefs. In this chapter, we will discuss


parametric


representations, where the belief distribution is represented by a set of


parameters of a fixed distribution family, such as the categorical or multivariate


normal distribution. We will also discuss


nonparametric


representations, where


the belief distribution is represented by particles, or points sampled from the state


space. Associated with the different representations are different procedures for


updating the belief based on the action taken by the agent and the observation.


Before the agent takes any actions or makes any observations, we start with


an initial belief distribution. If we have some prior information about where the


agent might be in the state space, we can encode this in the initial belief. We


generally want to use diffuse initial beliefs in the absence of information to avoid


being overly confident in the agent being in a region of the state space where it


might not actually be. A strong initial belief focused on states that are far from


the true state can lead to poor state estimates, even after many observations.


380


chapter 19. beliefs


A diffuse initial belief can cause difficulties, especially for nonparametric repre-


sentations of the belief, where the state space can be only very sparsely sampled.


In some cases, it may be useful to wait to initialize our beliefs until an informative


observation is made. For example, in robot navigation problems, we might want


to wait until the sensors detect a known


landmark


, and then initialize the belief


appropriately. The landmark can help narrow down the relevant region of the


state space so that we can focus our sampling of the space in the area consistent


with the landmark observation. Example 19.1 illustrates this concept.


Example 19.1. Generating an initial


Consider an autonomous car equipped with a localization system that uses


nonparametric belief based on a


camera, radar, and lidar data to track its position. The car is able to identify a


landmark observation. In this case,


the autonomous car could be any-


unique landmark at a range


and bearing


from its current pose:


where in a ring around the land-


mark:


landmark


car


landmark


The range and bearing measurements have zero-mean Gaussian noise with


variance


, respectively, and the landmark is known to be at


and


Given a measurement


and


, we can produce a distribution over the car’s


position


, ˆ


and orientation