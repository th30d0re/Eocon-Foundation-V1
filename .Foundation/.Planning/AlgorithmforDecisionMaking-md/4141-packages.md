---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Packages
---

# Packages

_Source page: 667_



package


is a collection of Julia code and possibly other external libraries that


can be imported to provide additional functionality. This section briefly reviews


a few of the key packages that we build upon in this book. To add a registered


package like


Distributions.jl


, we can run


using


Pkg


Pkg


add


"Distributions"


To update packages, we use


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


646


appendix g. julia


Pkg


update


()


To use a package, we use the keyword


using


as follows:


using


Distributions