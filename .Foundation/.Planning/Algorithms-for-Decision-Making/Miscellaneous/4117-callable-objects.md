---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Callable Objects
---

# Callable Objects

_Source page: 663_



We can define a type and associate functions with it, allowing objects of that type


to be


callable


julia>


(x


::


)()


# adding a zero-argument function to the type A defined earlier


julia>


(x


::


)(y)


# adding a single-argument function


julia>


A(


22


);


julia>


x()


30


julia>


x(


52