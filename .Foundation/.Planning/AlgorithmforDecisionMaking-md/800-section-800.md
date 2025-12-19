---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: ) =
---

# ) =

_Source page: 104_



. A common kernel is the zero-


mean Gaussian distribution. When such a kernel is used, the standard deviation


is often referred to as the


bandwidth


, which can be tuned to control the smoothness


of the density function. Larger bandwidths generally lead to smoother densities.


Bayesian methods can be applied to the selection of the appropriate bandwidth


based on the data. The effect of the bandwidth choice is shown in figure 4.5.


Algorithm


4.3.


The


method


gaussian_kernel


->


pdf


Normal


),


gaussian_kernel


returns


zero-mean Gaussian kernel


function


kernel_density_estimate


with bandwidth


. Kernel density


return


->


sum


([


for


in


])


length


estimation is also implemented for


end


a kernel


and list of observations