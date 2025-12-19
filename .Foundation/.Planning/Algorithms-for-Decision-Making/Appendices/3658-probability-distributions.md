---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Probability Distributions
---

# Probability Distributions

_Source page: 595_



This appendix summarizes several families of probability distributions relevant


These distributions are imple-


to the topics introduced in this book.


The distributions are represented by either


mented in


Distributions.jl


. M.


probability mass functions or probability density functions, and the relevant


Besançon, T. Papamarkou, D. An-


functions are provided, along with the parameters that govern each distribution.


thoff, A. Arslan, S. Byrne, D. Lin,


and J. Pearson, “Distributions.jl:


Plots show how the various parameters influence the distribution. The index


Definition and Modeling of Proba-


includes page references to where these distributions are used in the body of the


bility Distributions in the JuliaStats


Ecosystem,” 2019. arXiv: 1907.0861


book. Some distributions are


univariate


, meaning that they are distributions over


1v1.


a scalar variable; others are


multivariate


, meaning that they are distributions over


multiple variables.


Name


Parameters


Distribution Function


Uniform


lower bound


) =


upper bound


with


1,


0,


0.5


6,


5,


10


10


Gaussian


mean


) =


where


) =


exp


/2


(univariate)


variance


with


0.4


0,


0.3


0,


0.2


5,


0.1


3,


10


10


574


appendix b. probability distributions


Beta


shape


) =


Beta


shape


with