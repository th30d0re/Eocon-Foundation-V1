---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Abstract Types
---

# Abstract Types

_Source page: 660_



AbstractFloat


...


Float64


So far we have discussed


concrete types


, which are types that we can construct.


Float32


However, concrete types are only part of the type hierarchy. There are also


abstract


Float16


types


, which are supertypes of concrete types and other abstract types.


BigFloat


We can explore the type hierarchy of the


Float64


type shown in figure G.1


Figure G.1. The type hierarchy for


using the


supertype


and


subtypes


functions:


the


Float64


type.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


g.1. types


639


julia>


supertype(


Float64


AbstractFloat


julia>


supertype(


AbstractFloat


Real


julia>


supertype(


Real


Number


julia>


supertype(


Number


Any


julia>


supertype(


Any


# Any is at the top of the hierarchy


Any


julia>


using


InteractiveUtils


# required for using subtypes in scripts


julia>


subtypes(


AbstractFloat


# different types of AbstractFloats


4-element Vector{Any}:


BigFloat


Float16


Float32


Float64


julia>


subtypes(


Float64


# Float64 does not have any subtypes


Type[]


We can define our own abstract types:


abstract


type C


end


abstract


type D


<:


end


# D is an abstract subtype of C


struct


<:


# E is a composite type that is a subtype of D


end