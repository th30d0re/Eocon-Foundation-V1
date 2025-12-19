---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Named Tuples
---

# Named Tuples

_Source page: 659_



named tuple


is like a tuple, but each entry has its own name:


julia>


(a


, b


=-


Inf


(a = 1, b = -Inf)


julia>


isa NamedTuple


true


julia>


julia>


a, b


x;


julia>


julia>


(;


:a


=>


10


(a = 10,)


julia>


(;


:a


=>


10


:b


=>


11


(a = 10, b = 11)


julia>


merge(x, (d


, e


10


))


# merge two named tuples


(a = 1, b = -Inf, d = 3, e = 10)