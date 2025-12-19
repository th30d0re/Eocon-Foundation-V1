---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Automated Driving
---

# Automated Driving

_Source page: 25_



We want to build an autonomous vehicle that can safely drive in urban environ-


A similar application was ex-


ments.


The vehicle must rely on a suite of sensors to perceive its environment in


plored by M. Bouton, A. Nakhaei,


order to make safe decisions. One type of sensor is lidar, which involves measuring


K. Fujimura, and M. J. Kochender-


laser reflections off the environment to determine distances to obstacles. Another


fer, “Safe Reinforcement Learning


with Scene Decomposition for Nav-


type of sensor is a camera, which, through computer vision algorithms, can detect


igating Complex Urban Environ-


pedestrians and other vehicles. Both of these types of sensors are imperfect and


ments,” in


IEEE Intelligent Vehicles


Symposium (IV)


, 2019.


susceptible to noise and occlusions. For example, a parked truck may occlude a


pedestrian who may be trying to cross at a crosswalk. Our system must predict the


intentions and future paths of other vehicles, pedestrians, and other road users


from their observable behaviors in order to navigate safely to our destination.