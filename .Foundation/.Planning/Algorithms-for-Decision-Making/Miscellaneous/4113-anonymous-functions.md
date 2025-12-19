---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Anonymous Functions
---

# Anonymous Functions

_Source page: 662_



An


anonymous function


is not given a name, though it can be assigned to a named


variable. One way to define an anonymous function is to use the arrow operator:


julia>


->


# assign anonymous function with input x to a variable h


#1 (generic function with 1 method)


julia>


h(


10


julia>


g(f, a, b)


[f(a), f(b)];


# applies function f to a and b and returns array


julia>


g(h,


10


2-element Vector{Int64}:


26


101


julia>


g(x


->


sin(x)


10


20


2-element Vector{Float64}: