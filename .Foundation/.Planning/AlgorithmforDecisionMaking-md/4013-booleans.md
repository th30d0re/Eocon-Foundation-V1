---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Booleans
---

# Booleans

_Source page: 649_



The


Boolean


type in Julia, written as


Bool


, includes the values


true


and


false


. We


can assign these values to variables. Variable names can be any string of characters,


including Unicode, with a few restrictions.


true


done


false


The variable name appears on the left side of the equal sign; the value that variable


is to be assigned is on the right side.


628


appendix g. julia


We can make assignments in the Julia console. The console, or REPL (for read,


eval, print, loop), will return a response to the expression being evaluated. The


symbol indicates that the rest of the line is a comment.


julia>


true


true


julia>


false


# semicolon suppresses the console output


julia>


typeof(x)


Bool


julia>


==


# test for equality


false


The standard Boolean operators are supported:


julia>


# not


false


julia>


&&


# and


false


julia>


||


# or


true