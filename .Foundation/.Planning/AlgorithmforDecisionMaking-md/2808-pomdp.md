---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 460_



the upper bound at each iteration,


basis


updates are not made at the stan-


SawtoothPolicy


dard basis beliefs stored in


. We


for


in 1


k_max


run


k_max


iterations.


Dict


=>


greedy


).


for


in


SawtoothPolicy


end


return


end


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


21.6. sawtooth upper bound


439


Example 21.1. An illustration of


Suppose that we want to maintain an upper bound of the value for the crying


sawtooth’s ability to maintain an


baby problem with regularly spaced belief points with a step size of


0.2


. To


upper bound at regularly spaced


beliefs for the crying baby prob-


obtain an initial upper bound, we use the fast informed bound. We can then


lem.


run sawtooth iteration for three steps as follows:


length


πfib


solve


FastInformedBound


),


Dict


=>


utility


πfib


for


in


basis


))


[[


for


in 0.0


0.2


1.0


solve


SawtoothIteration


),


The sawtooth upper bound improves as follows:


iteration


bound


iteration


bound


iteration


bound


10


10


10


15


15


15


0.2


0.6


0.8


0.2


0.6


0.8


0.2


0.6


0.8


0.4


0.4


0.4


hungry


hungry


hungry


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


440


chapter 21. offline belief state planning