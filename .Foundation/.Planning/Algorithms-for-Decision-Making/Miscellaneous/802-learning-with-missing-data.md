---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: Learning with Missing Data
---

# Learning with Missing Data

_Source page: 104_



When learning the parameters of our probabilistic model we may have


missing


Learning with missing data is the


entries in our data.


For example, if we are conducting a survey, some respondents


subject of a large body of litera-


may decide to skip a question. Table 4.1 shows an example of a data set with


ture. A comprehensive introduc-


missing entries involving three binary variables:


, and


. One approach to


tion and review is provided by G.


Molenberghs, G. Fitzmaurice, M. G.


handling missing data is to discard all the instances that are


incomplete


, where


Kenward, A. Tsiatis, and G. Ver-


there are one or more missing entries. Depending on how much of the data is


beke, eds.,


Handbook of Missing Data


Methodology


. CRC Press, 2014.


missing, we might have to discard much of it. In table 4.1, we would have to


discard all but one of the rows, which can be wasteful.


© 2022 Massachusetts Institute of Technology, shared under a Creative Commons CC-BY-NC-ND license.


2025-09-21 10:49:56-07:00, comments to bugs@algorithmsbook.com


4.4. learning with missing data


83


Figure 4.5. Kernel density estima-


bandwidth