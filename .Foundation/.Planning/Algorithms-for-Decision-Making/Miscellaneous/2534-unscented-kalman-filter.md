---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Unscented Kalman Filter
---

# Unscented Kalman Filter

_Source page: 409_



S. J. Julier and J. K. Uhlmann, “Un-


The


unscented Kalman filter


UKF


is another extension to the Kalman filter to


scented Filtering and Nonlinear Es-


problems that are nonlinear with Gaussian noise.


Unlike the extended Kalman


timation,”


Proceedings of the IEEE


filter, the unscented Kalman filter is derivative free, and relies on a determinis-


vol. 92, no. 3, pp. 401–422, 2004.


According to Jeffrey K. Uhlmann,


tic sampling strategy to approximate the effect of a distribution undergoing a


the term ‘‘unscented’’ comes from


(typically nonlinear) transformation.


a label on a deodorant container


The unscented Kalman filter was developed to estimate the effect of transform-


that he saw on someone’s desk.


He used that term to avoid call-


ing a distribution over


with a nonlinear function


, producing a distribution


ing it the ‘‘Uhlmann filter.’’ IEEE


over


. We would like to estimate the mean


and covariance


of the distribu-


History Center Staff, “Proceedings


tion over


. The unscented transform allows for more information of


to be


of the IEEE Through 100 Years: