---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: · · ·
---

# · · ·

_Source page: 70_



In the naive Bayes model, class


is the query variable, and the observed


Observed features


features


1:


are the evidence variables. The naive Bayes model is called naive


Figure 3.2. A naive Bayes model.


because it assumes conditional independence between the evidence variables


given the class. Using the notation introduced in section 2.6, we can say


Class


for all


. Of course, if these conditional independence assumptions do


not hold, then we can add the necessary directed edges between the observed


features.


Observed features


We have to specify the


prior


and the


class-conditional distributions


1 :


As done in the previous section, we can apply the chain rule to compute the joint


distribution:


Figure 3.3. Plate representation of


a naive Bayes model.