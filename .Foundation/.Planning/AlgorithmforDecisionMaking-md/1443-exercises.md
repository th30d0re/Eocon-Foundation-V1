---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Exercises
---

# Exercises

_Source page: 231_



Exercise 9.1.


Why does branch and bound have the same worst-case computational


complexity as forward search?


Solution:


In the worst case, branch and bound will never prune, resulting in a traversal of


the same search tree as forward search with the same complexity.


Exercise 9.2.


Given two admissible heuristics


, how can we use both of them in


and


heuristic search?


Solution:


Create a new heuristic


) =


min


and use it instead. This new


heuristic is guaranteed to be admissible and cannot be a worse bound than either


or


Both


and


imply that


Exercise 9.3.


Given two inadmissible heuristics


, describe a way we can use both


and


of them in heuristic search.


Solution:


We could define a new heuristic


) =


max


))


to get a potentially


admissible, or ‘‘less-inadmissible,’’ heuristic. It may be slower to converge, but it may be


more likely to not miss out on a better solution.


Exercise 9.4.


Suppose we have a discrete MDP with state space


and action space


and


we want to perform forward search to depth


. Due to computational constraints and the


requirement that we must simulate to depth


, we decide to generate new, smaller state and


action spaces by re-discretizing the original state and action spaces on a coarser scale with


|S


|S|


and


|A


|A|


. In terms of the original state and action spaces, what would


the size of the new state and action spaces need to be in order to make the computational


complexity of forward search approximately depth-invariant with respect to the size of


our original state and action spaces, that is,