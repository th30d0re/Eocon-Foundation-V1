---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Aircraft Collision Avoidance
---

# Aircraft Collision Avoidance

_Source page: 636_



The


aircraft collision avoidance problem


involves deciding when to issue a climb or


This formulation is a highly sim-


descend advisory to an aircraft to avoid an intruder aircraft.


There are three


plified version of the problem de-


actions corresponding to no advisory, commanding a


5 m/s


descend, and com-


scribed by M. J. Kochenderfer and


manding a


5 m/s


climb. The intruder is approaching us head on, with a constant


J. P. Chryssanthacopoulos, “Ro-


bust Airborne Collision Avoidance


horizontal closing speed. The state is specified by the altitude


of our aircraft


Through Dynamic Programming,”


measured relative to the intruder aircraft, our vertical rate


, the previous action


Massachusetts Institute of Technol-


ogy, Lincoln Laboratory, Project Re-


, and the time to potential collision


. Figure F.8 illustrates the problem


prev


col


port ATC-371, 2011.


scenario.


Given action


, the state variables are updated as follows: