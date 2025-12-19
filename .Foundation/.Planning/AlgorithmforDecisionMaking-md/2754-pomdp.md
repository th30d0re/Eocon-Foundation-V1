---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: POMDP
---

# POMDP

_Source page: 453_



Algorithm 21.4. Implementation


maximum


minimum


for


in


for


in


of the best-action worst-state lower


fill


length


))


bound from equation (21.5) repre-


return


sented as an alpha vector.


end


The


blind lower bound


(algorithm 21.5) represents a lower bound with one alpha


vector per action. It makes the assumption that we are forced to commit to a single


action forever, blind to what we observe in the future. To compute these alpha


vectors, we start with another lower bound (typically the best-action worst-state


lower bound) and then perform a number of iterations: