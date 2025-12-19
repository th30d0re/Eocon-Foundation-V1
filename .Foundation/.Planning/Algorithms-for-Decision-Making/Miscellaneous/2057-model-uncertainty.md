---
converted: '2025-10-25'
source: AlgorithmforDecisionMaking.pdf
title: model uncertainty
---

# model uncertainty

_Source page: 319_



In our discussion of sequential decision problems thus far, we have assumed that


the transition and reward models are known. In many problems, however, these


models are not known exactly, and the agent must learn to act through experience.


By observing the outcomes of its actions in the form of state transitions and


rewards, the agent is to choose actions that maximize its long-term accumulation


of rewards. Solving such problems in which there is model uncertainty is the


subject of the field of


reinforcement learning


, which is the focus of this part of


the book. We will discuss several challenges in addressing model uncertainty.


First, the agent must carefully balance exploration of the environment with the


exploitation of that knowledge gained through experience. Second, rewards may


be received long after the important decisions have been made, so credit for later


rewards must be assigned to earlier decisions. Third, the agent must generalize


from limited experience. We will review the theory and some of the key algorithms


for addressing these challenges.