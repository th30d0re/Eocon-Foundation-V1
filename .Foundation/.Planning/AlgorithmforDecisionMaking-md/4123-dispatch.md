---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Dispatch
---

# Dispatch

_Source page: 664_



The types of the arguments passed to a function can be specified using the double


colon operator. If multiple methods of the same function are provided, Julia will


execute the appropriate method. The mechanism for choosing which method to


execute is called


dispatch


julia>


f(x


::


Int64


10


julia>


f(x


::


Float64