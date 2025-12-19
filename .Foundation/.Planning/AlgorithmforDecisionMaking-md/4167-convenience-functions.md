---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Convenience Functions
---

# Convenience Functions

_Source page: 670_



There are a few functions that allow us to specify the algorithms in this book more


compactly. The following functions are useful when working with dictionaries


and named tuples:


Base


Dict


Symbol


}(


::


NamedTuple


where V


Dict


Symbol


}(


=>


for


in


zip


keys


),


values


)))


Base


convert


::


Type


Dict


Symbol


}},


::


NamedTuple


where V


Dict


Symbol


}(


Base


isequal


::


Dict


Symbol


<:


Any


},


nt


::


NamedTuple


length


==


length


nt


&&


all


==


for


in


zip


keys


nt


),


values


nt


)))


julia>


Dict


Symbol


Integer


}((a


, b


, c


))


Dict{Symbol, Integer} with 3 entries:


:a => 1


:b => 2


:c => 3


julia>


isequal(a, (a


, b


, c


))


true


julia>


isequal(a, (a


, c


, b


))


true


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


g.5. convenience functions


649


julia>


Dict


Dict


Symbol


Integer


},


Float64


}((a


, b


=>


0.2


, (a


, b


=>


0.8


Dict{Dict{Symbol, Integer}, Float64} with 2 entries:


Dict(:a=>1, :b=>1) => 0.2


Dict(:a=>1, :b=>2) => 0.8


We define


SetCategorical


to represent distributions over discrete sets:


struct


SetCategorical


elements


::


Vector


# Set elements (could be repeated)


distr


::


Categorical


# Categorical distribution over set elements


function


SetCategorical


elements


::


AbstractVector


})


where S


weights


ones


length


elements


))


return


new


}(


elements


Categorical


normalize


weights


)))


end


function


SetCategorical


elements


::


AbstractVector


},


weights


::


AbstractVector


Float64


where S


ℓ₁


norm


weights


if


ℓ₁


1e-6


||


isinf


ℓ₁


return


SetCategorical


elements


end


distr


Categorical


normalize


weights


))


return


new


}(


elements


distr


end


end


Distributions


rand


::


SetCategorical


elements


rand


distr


)]


Distributions


rand


::


SetCategorical


::


Int


elements


rand


distr


)]


function


Distributions


pdf


::


SetCategorical


sum


==


0.0 for


in


zip


elements


distr


))


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


650


appendix g. julia


julia>


SetCategorical([


"up"


"down"


"left"


"right"


],[


0.4


0.2


0.3


0.1


]);


julia>


rand(D)


"up"


julia>


rand(D,


5-element Vector{String}:


"left"


"left"


"down"


"down"


"left"


julia>


pdf(D,


"up"