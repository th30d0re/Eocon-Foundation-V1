---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: PSPACE
---

# PSPACE

_Source page: 599_



contains the set of all problems that can be solved with a polynomial


Plenum, 1972, pp. 85–103.


amount of space, without any considerations about time. There is a fundamental


difference between time and space complexity, in that time cannot be reused, but


space can be. We know that P and NP are subsets of PSPACE. It is not yet known,


but it is suspected, that PSPACE includes problems not in NP. Through polynomial


time transformations, we can define


PSPACE-hard


and


PSPACE-complete


classes,


just as we did with NP-hard and NP-complete classes.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


578


appendix c. computational complexity


Example C.3.


The 3SAT prob-


The problem of


Boolean satisfiability


involves determining whether a Boolean


lem, which is the first known NP-


formula is


satisfiable


. The Boolean formula consists of conjunctions (


), dis-


complete problem.


junctions (


), and negations (


) involving


Boolean variables


, . . .


. A


literal is a variable


. A 3SAT clause is a disjunction of


or its negation


up to three literals (e.g.,


). A 3SAT formula is a conjunction of