---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Genetic Algorithms
---

# Genetic Algorithms

_Source page: 237_



D. E. Goldberg,


Genetic Algorithms


in Search, Optimization, and Machine


A potential issue with local search algorithms like the Hooke-Jeeves method is


Learning


. Addison-Wesley, 1989.


that the optimization can get stuck in a local optimum. There are a wide variety of


F. P. Such, V. Madhavan, E. Conti,


approaches that involve maintaining a


population


consisting of samples of points


J. Lehman, K. O. Stanley, and J.


in the parameter space, evaluating them in parallel with respect to our objective,


Clune, “Deep Neuroevolution: Ge-


and then recombining them in some way to drive the population toward a global


netic Algorithms Are a Competi-


tive Alternative for Training Deep


optimum. A


genetic algorithm


is one such approach, which derives inspiration


Neural Networks for Reinforce-


from biological evolution. It is a general optimization method, but it has been


ment Learning,” 2017. arXiv: 171


2.06567v3. The implementation in


successful in the context of optimizing policies. For example, this approach has


this section follows their relatively


been used to optimize policies for Atari video games, where the policy parameters


simple formulation. Their formu-


correspond to weights in a neural network.


lation does not include crossover,


which is typically used to mix pa-


A simple version of this approach (algorithm 10.3) begins with a population of


rameterizations across a popula-


random parameterizations,