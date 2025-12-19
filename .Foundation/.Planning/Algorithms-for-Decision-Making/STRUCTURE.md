# Algorithms for Decision Making - Structure Summary

**Book:** Algorithms for Decision Making  
**Authors:** Mykel J. Kochenderfer, Tim A. Wheeler, Kyle H. Wray  
**Publisher:** The MIT Press  
**Conversion Date:** 2025-10-25  

## 📚 Complete Book Structure

This document provides a complete overview of how the PDF has been converted and organized into structured markdown files.

---

## 📂 Directory Organization

```
Algorithms-for-Decision-Making/
├── README.md                          # Main book index
├── STRUCTURE.md                       # This file
├── Front-Matter/                      # Title pages, preface, TOC
├── Part-I-Probabilistic-Reasoning/    # Chapters 1-6
│   ├── README.md
│   ├── Chapter-01/                    # Introduction
│   ├── Chapter-02/                    # Representation
│   ├── Chapter-03/                    # Inference
│   ├── Chapter-04/                    # Parameter Learning
│   ├── Chapter-05/                    # Structure Learning
│   └── Chapter-06/                    # Simple Decisions
├── Part-II-Sequential-Problems/       # Chapters 7-14
│   ├── README.md
│   ├── Chapter-07/                    # Exact Solution Methods
│   ├── Chapter-08/                    # Approximate Value Functions
│   ├── Chapter-09/                    # Online Planning
│   ├── Chapter-10/                    # Policy Search
│   ├── Chapter-11/                    # Policy Gradient Estimation
│   ├── Chapter-12/                    # Policy Gradient Optimization
│   ├── Chapter-13/                    # Actor-Critic Methods
│   └── Chapter-14/                    # Policy Validation
├── Part-III-Model-Uncertainty/        # Chapters 15-18
│   ├── README.md
│   ├── Chapter-15/                    # Exploration and Exploitation
│   ├── Chapter-16/                    # Model-Based Methods
│   ├── Chapter-17/                    # Model-Free Methods
│   └── Chapter-18/                    # Imitation Learning
├── Part-IV-State-Uncertainty/         # Chapters 19-23
│   ├── README.md
│   ├── Chapter-19/                    # Beliefs
│   ├── Chapter-20/                    # Exact Belief State Planning
│   ├── Chapter-21/                    # Offline Belief State Planning
│   ├── Chapter-22/                    # Online Belief State Planning
│   └── Chapter-23/                    # Controller Abstractions
├── Part-V-Multiagent-Systems/         # Chapters 24-27
│   ├── README.md
│   ├── Chapter-24/                    # Multiagent Reasoning
│   ├── Chapter-25/                    # Sequential Problems
│   ├── Chapter-26/                    # State Uncertainty
│   └── Chapter-27/                    # Collaborative Agents
├── Appendices/                        # Mathematical concepts, etc.
├── Back-Matter/                       # References, Index
└── Miscellaneous/                     # Uncategorized files
```

---

## 📖 Part I: Probabilistic Reasoning (Chapters 1-6)

**Focus:** Foundations of probabilistic reasoning and decision making

### Chapter 1: Introduction
- Decision making under uncertainty
- Applications (aircraft collision avoidance, autonomous driving, etc.)
- Methods (explicit programming, supervised learning, optimization, planning, RL)
- Historical perspectives
- Societal impact

### Chapter 2: Representation
- Probability distributions (discrete, continuous)
- Joint distributions
- Conditional distributions
- Bayesian networks
- Conditional independence

### Chapter 3: Inference
- Inference in Bayesian networks
- Variable elimination
- Belief propagation
- Direct sampling
- Likelihood weighted sampling
- Gibbs sampling
- Inference in Gaussian models

### Chapter 4: Parameter Learning
- Maximum likelihood parameter learning
- Bayesian parameter learning
- Learning with missing data (EM algorithm)

### Chapter 5: Structure Learning
- Constraint-based learning
- Score-based learning
- Bayesian structure learning

### Chapter 6: Simple Decisions
- Utility theory
- Maximum expected utility
- Decision networks
- Value of information

---

## 📖 Part II: Sequential Problems (Chapters 7-14)

**Focus:** Markov Decision Processes and Reinforcement Learning

### Chapter 7: Exact Solution Methods
- Markov decision processes (MDPs)
- Policy evaluation
- Value iteration
- Policy iteration
- Linear programming

### Chapter 8: Approximate Value Functions
- Function approximation
- Linear regression
- Neural network approximation
- Fitted value iteration

### Chapter 9: Online Planning
- Forward search
- Branch and bound
- Monte Carlo tree search (MCTS)
- Heuristic search

### Chapter 10: Policy Search
- Policy gradient methods
- Genetic algorithms
- Cross-entropy method
- Evolution strategies

### Chapter 11: Policy Gradient Estimation
- Likelihood ratio gradient estimation
- Reward-to-go estimation
- Baselines
- Finite difference methods

### Chapter 12: Policy Gradient Optimization
- Gradient ascent
- Trust region methods (TRPO)
- Natural policy gradients
- Proximal policy optimization (PPO)

### Chapter 13: Actor-Critic Methods
- Advantage estimation
- Generalized advantage estimation (GAE)
- Asynchronous advantage actor-critic (A3C)
- Deep deterministic policy gradient (DDPG)

### Chapter 14: Policy Validation
- Policy evaluation
- Statistical tests
- Confidence intervals
- Importance sampling

---

## 📖 Part III: Model Uncertainty (Chapters 15-18)

**Focus:** Learning and decision making with uncertain environment models

### Chapter 15: Exploration and Exploitation
- Multi-armed bandits
- Exploration strategies (ε-greedy, UCB, Thompson sampling)
- Contextual bandits
- Regret bounds

### Chapter 16: Model-Based Methods
- Model learning
- R-MAX algorithm
- Posterior sampling
- Bayesian reinforcement learning

### Chapter 17: Model-Free Methods
- Temporal difference learning
- Q-learning
- SARSA
- Deep Q-networks (DQN)

### Chapter 18: Imitation Learning
- Behavioral cloning
- Dataset aggregation (DAgger)
- Inverse reinforcement learning
- Generative adversarial imitation learning (GAIL)

---

## 📖 Part IV: State Uncertainty (Chapters 19-23)

**Focus:** Partially Observable Markov Decision Processes (POMDPs)

### Chapter 19: Beliefs
- Belief states
- Belief updating
- Kalman filters
- Extended Kalman filter (EKF)
- Unscented Kalman filter (UKF)
- Particle filters

### Chapter 20: Exact Belief State Planning
- POMDP formulation
- Value iteration for POMDPs
- Policy trees
- Exact dynamic programming

### Chapter 21: Offline Belief State Planning
- Point-based value iteration
- SARSOP algorithm
- Heuristic search value iteration (HSVI)
- Sawtooth approximations

### Chapter 22: Online Belief State Planning
- Forward search in belief space
- POMCP algorithm
- Sparse sampling
- Determinized sparse tree search (DESPOT)

### Chapter 23: Controller Abstractions
- Finite-state controllers
- Policy iteration for controllers
- Nonlinear programming approaches
- Controller optimization

---

## 📖 Part V: Multiagent Systems (Chapters 24-27)

**Focus:** Game theory and multiagent decision making

### Chapter 24: Multiagent Reasoning
- Simple games
- Response models
- Nash equilibrium
- Correlated equilibrium
- Iterated best response
- Gradient ascent

### Chapter 25: Sequential Problems
- Markov games
- Nash equilibrium in Markov games
- Fictitious play
- Gradient ascent methods

### Chapter 26: State Uncertainty
- Partially observable Markov games (POMGs)
- Policy evaluation in POMGs
- Nash equilibrium computation
- Dynamic programming for POMGs

### Chapter 27: Collaborative Agents
- Decentralized POMDPs
- Subclasses (ND-POMDP, MMDP, MPOMDP)
- Dynamic programming methods
- Heuristic search approaches

---

## 📎 Appendices

- **Appendix A:** Mathematical Concepts (measure theory, probability, convexity, etc.)
- **Appendix B:** Probability Distributions (common distributions and their properties)
- **Appendix C:** Computational Complexity (P, NP, PSPACE, decidability)
- **Appendix D:** Neural Network Representations (feedforward, CNN, RNN, LSTM, etc.)
- **Appendix E:** Search Algorithms (graph search, A*, branch and bound, etc.)
- **Appendix F:** Example Problems (2048, cart pole, mountain car, hex world, etc.)
- **Appendix G:** Julia Programming Guide (types, functions, packages, etc.)

---

## 📊 Statistics

- **Total Chapters:** 27
- **Total Parts:** 5
- **Total Markdown Files:** ~4,200+
- **Organized Files:** ~1,400
- **File Format:** Markdown with YAML frontmatter
- **Source Pages:** ~600+ (from original PDF)

---

## 🔍 How to Navigate

1. **Start at the main README:** `README.md`
2. **Browse by Part:** Each part has its own `README.md` with chapter links
3. **Dive into Chapters:** Each chapter directory contains:
   - `README.md` - Chapter overview and file index
   - Section files - Individual markdown files for each section
4. **Cross-reference:** Use the appendices for mathematical background and examples

---

## 📝 File Naming Convention

Files are named using the pattern: `{number}-{title}.md`

- **Number prefix:** Original position/identifier from PDF conversion
- **Title:** Descriptive name (chapter, section, or topic)
- **Examples:**
  - `188-1-1.md` - Chapter 1, Section 1
  - `187-introduction.md` - Introduction chapter
  - `521-inference.md` - Inference chapter

---

## 🛠️ Conversion Process

1. **PDF → Markdown:** Original PDF converted to individual markdown files
2. **Metadata Extraction:** YAML frontmatter added to each file
3. **Structure Analysis:** Files analyzed and categorized by content
4. **Organization:** Files moved into hierarchical folder structure
5. **Index Generation:** README files created for navigation

---

## ✅ Quality Assurance

- ✓ All 27 chapters organized
- ✓ 5 parts properly structured
- ✓ Chapter READMEs generated
- ✓ Part READMEs created
- ✓ Main index completed
- ✓ Navigation links established
- ✓ File metadata preserved

---

## 🎯 Usage Recommendations

**For Students:**
- Follow the sequential chapter order for systematic learning
- Use chapter READMEs to understand content organization
- Reference appendices for mathematical background

**For Researchers:**
- Jump directly to relevant chapters using the main index
- Use the part-level organization to focus on specific topics
- Leverage cross-references between chapters

**For Instructors:**
- Each part can serve as a unit in a course
- Chapter organization facilitates assignment creation
- Example problems in Appendix F useful for homework

---

## 📚 Original Source

**PDF File:** `AlgorithmforDecisionMaking.pdf`  
**Publisher:** The MIT Press  
**License:** Educational use - respect original copyright  

---

## 🔄 Updates and Maintenance

This structured version was created on **2025-10-25** using automated
conversion and organization scripts:

- `reorganize_book.py` - Main file organization script
- `create_chapter_indexes.py` - README generation script

For updates or corrections, regenerate using these scripts on the source
markdown files in `AlgorithmforDecisionMaking-md/`.

---

*Last Updated: 2025-10-25*
*Structure Version: 1.0*