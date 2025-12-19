---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Summary
---

# Summary

_Source page: 197_



For large or continuous problems, we can attempt to find approximate policies


represented by parameterized models of the value function.


The approaches taken in this chapter involve iteratively applying steps of


dynamic programming at a finite set of states and refining our parametric


approximation.


Local approximation techniques approximate the value function based on the


values of nearby states with known values.


A variety of local approximation techniques include nearest neighbor, kernel


smoothing, linear interpolation, and simplex interpolation.


Global approximation techniques include linear regression and neural network


regression.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


176


chapter 8. approximate value functions


Example 8.3.


Linear regression


We can apply linear regression to learn a value function for the mountain car


using Fourier bases used to ap-


problem. The optimal value function has the form of a spiral, which can be


proximate the value function for


the mountain car problem (ap-


difficult to approximate with polynomial basis functions (see example 8.2).


pendix F.4). Value functions (top


We use Fourier basis functions whose components take the following form:


row) and resulting policies (bot-


tom row) are shown. The globally