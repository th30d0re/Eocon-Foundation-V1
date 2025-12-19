---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Heuristic Search
---

# Heuristic Search

_Source page: 626_



memoization


Heuristic search is also known as


Heuristic search


(algorithm E.5) improves on branch and bound by ordering its


informed search


or


best-first search


actions based on a provided heuristic function


, which is an upper bound


Our implementation does use two


of the return. Like dynamic programming, heuristic search has a mechanism by


value functions: the heuristic for


which state evaluations can be cached to avoid redundant computation. Further-


guiding the search and an approxi-


more, heuristic search does not require the lower bound value function needed


mate value function for evaluating


terminal states.


by branch and bound.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


e.6. heuristic search


605


Algorithm E.4. Dynamic program-


function


dynamic_programming


::


Search


Dict


())


ming applied to forward search,


if


haskey


, (


))


which includes a transposition ta-


return


[(


)]


ble


. Here,


is a dictionary that


end


stores depth-state tuples from pre-


),


vious evaluations, allowing the


if


isempty


||


method to return previously com-


best


nothing


))


else


puted results. The search is per-


best


first


),


=-


Inf


formed to depth


, at which point


for


in


the terminal value is estimated


s′


with an approximate value func-


dynamic_programming


s′


-1


).


tion


. The returned named tuple


if


best


consists of the best action


and its


best


finite-horizon expected value


end


end


end


[(


)]


best


return


best


end


Figure E.5. A comparison of the


10


forward search


number of state evaluations for


with DP


pure forward search and forward


10


search augmented with dynamic


programming on the hex-world


search problem of example E.1.


10


Dynamic programming is able to


avoid the exponential growth in


state visitation by caching results.


10


number of state evaluations


depth


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


606


appendix e. search algorithms


Algorithm E.5.


The heuristic


function


heuristic_search


::


Search


Uhi


search algorithm for solving a


if


haskey


, (


))


search problem


starting from


return


[(


)]


state


and searching to a maxi-


end


mum depth


. A heuristic


Uhi


is


),


used to guide the search, the ap-


if


isempty


||


proximate value function


is evalu-


best


nothing


))


else


ated at terminal states, and a trans-


best


first


),


=-


Inf


position table


in the form of a dic-


for


in


sort


by


->


Uhi


)),


rev


true


tionary containing depth-state tu-


if


Uhi


))


best


ples allows the algorithm to cache


break


values from previously explored


end


states.


s′


heuristic_search


s′


-1


Uhi


).


if


best


best


end


end


end


[(


)]


best


return


best


end


Actions are sorted based on the immediate reward plus a heuristic estimate of


the future return: