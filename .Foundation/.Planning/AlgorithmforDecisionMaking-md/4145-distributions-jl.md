---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Distributions.jl
---

# Distributions.jl

_Source page: 668_



We use the


Distributions.jl


package (version 0.24) to represent, fit, and sample


from probability distributions:


julia>


using


Distributions


julia>


dist


Categorical([


0.3


0.5


0.2


])


# create a categorical distribution


Distributions.Categorical{Float64, Vector{Float64}}(support=Base.OneTo(3), p=[0.3, 0.5, 0.2])


julia>


data


rand(dist)


# generate a sample


julia>


data


rand(dist,


# generate two samples


2-element Vector{Int64}:


julia>


μ, σ


5.0


2.5


# define parameters of a normal distribution


julia>


dist


Normal(μ, σ)


# create a normal distribution


Distributions.Normal{Float64}(μ=5.0, σ=2.5)


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


g.4. packages


647


julia>


rand(dist)


# sample from the distribution