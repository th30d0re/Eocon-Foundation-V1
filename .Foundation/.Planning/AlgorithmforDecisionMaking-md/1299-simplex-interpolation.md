---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Simplex Interpolation
---

# Simplex Interpolation

_Source page: 190_



a two-dimensional grid results in


a contribution of each vertex equal


Multilinear interpolation can be inefficient in high dimensions. Rather than


to the relative area of its opposing


quadrant:


) =


weighting the contributions of


points,


simplex interpolation


considers only


points in the neighborhood of a given state to produce a continuous surface that


matches the known sample points.


We start with a multidimensional grid and divide each cell into


simplexes


which are multidimensional generalizations of triangles defined by the


convex hull


Figure 8.9. Two-dimensional linear


of


vertices. This process is known as


Coxeter-Freudenthal-Kuhn triangulation


interpolation over a


grid.


and it ensures that any two simplexes that share a face will produce equivalent


A. W. Moore, “Simplicial Mesh


values across the face, thus producing continuity when interpolating, as shown


Generation with Applications,”


Ph.D. dissertation, Cornell Univer-


in figure 8.10.


sity, 1992.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


8.5. simplex interpolation


169


Algorithm 8.4. A method for con-


mutable struct


MultilinearValueFunction


ducting multilinear interpolation


# position of lower-left corner


to estimate the value of state vec-


# vector of widths


tor


for known state values


over


# vector of values at states in S


a grid defined by a lower-left ver-


end


tex


and vector of widths


. Ver-


function


Uθ


::


MultilinearValueFunction


)(


tices of the grid can all be writ-


Uθ


Uθ


Uθ


ten


for some nonnega-


).


tive integral vector


. The package


# Multidimensional index of lower-left cell


Interpolations.jl


also provides


min.


floor.


Int


) .


size


) .


multilinear and other interpolation


vertex_index


similar


methods.


length


0.0


for


vertex


in 0


-1


weight


1.0


for


in 1


# Check whether jth bit is set


if


vertex


<<


-1


))


vertex_index


weight


*=


else


vertex_index


weight


*=


end


end


+=


vertex_index