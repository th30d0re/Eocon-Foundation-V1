---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Composite Types
---

# Composite Types

_Source page: 660_



composite type


is a collection of named fields. By default, an instance of a com-


posite type is immutable (i.e., it cannot change). We use the


struct


keyword and


then give the new type a name and list the names of the fields:


struct


end


Adding the keyword


mutable


makes it so that an instance can change:


mutable struct


end


Composite types are constructed using parentheses, between which we pass


in values for each field: