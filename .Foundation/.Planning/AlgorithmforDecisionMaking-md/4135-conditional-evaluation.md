---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Conditional Evaluation
---

# Conditional Evaluation

_Source page: 665_



Conditional evaluation will check the value of a Boolean expression and then


evaluate the appropriate block of code. One of the most common ways to do this


is with an


if


statement:


if


# run this if x < y


elseif


# run this if x > y


else


# run this if x == y


end


We can also use the


ternary operator


with its question mark and colon syntax.


It checks the Boolean expression before the question mark. If the expression


evaluates to true, then it returns what comes before the colon; otherwise, it


returns what comes after the colon:


julia>


f(x)


julia>


f(


10


julia>


f(


10


10


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


644


appendix g. julia