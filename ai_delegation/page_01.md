# Page 1

2026-02-12
Intelligent AI Delegation
Nenad Tomašev1, Matija Franklin1 and Simon Osindero1
1Google DeepMind
AI agents are able to tackle increasingly complex tasks. To achieve more ambitious goals, AI agents need
to be able to meaningfully decompose problems into manageable sub-components, and safely delegate
their completion across to other AI agents and humans alike. Yet, existing task decomposition and
delegation methods rely on simple heuristics, and are not able to dynamically adapt to environmental
changes and robustly handle unexpected failures. Here we propose an adaptive framework forintelligent
AI delegation- a sequence of decisions involving task allocation, that also incorporates transfer of
authority, responsibility, accountability, clear specifications regarding roles and boundaries, clarity
of intent, and mechanisms for establishing trust between the two (or more) parties. The proposed
frameworkisapplicabletobothhumanandAIdelegatorsanddelegateesincomplexdelegationnetworks,
aiming to inform the development of protocols in the emerging agentic web.
Keywords: AI, agents, LLM, delegation, multi-agent, safety
1. Introduction
As advanced AI agents evolve beyond query-
response models, their utility is increasingly de-
fined by how effectively they can decompose com-
plex objectives and delegate sub-tasks. This coor-
dination paradigm underpins applications rang-
ing from personal use, where AI agents can act
as personal assistants (Gabriel et al., 2024), to
commercial, enterprise deployments where AI
agents can provide support and automate work-
flows (Huang and Hughes, 2025; Shao et al.,
2025; Tupe and Thube, 2025). Large language
models (LLMs) have already shown promise in
robotics (Li et al., 2025a; Wang et al., 2024a),
by enabling more interactive and accurate goal
specificationandfeedback. Recentproposalshave
also highlighted the possibility of large-scale AI
agentcoordinationinvirtualeconomies(Tomasev
et al., 2025). Modern agentic AI systems imple-
ment complex control flows across differentiated
sub-agents, coupledwithcentralizedordecentral-
ized orchestration protocols (Hong et al., 2023;
Rasal and Hauer, 2024; Song et al., 2025; Zhang
et al., 2025a). This can already be seen as a
sort of a microcosm of task decomposition and
delegation, where the process is hard-coded and
highly constrained. Managing dynamic web-scale
interactions requires us to think beyond the ap-
proaches that are currently employed by more
heuristic multi-agent frameworks.
Delegation (Castelfranchi and Falcone, 1998)
is more than just task decomposition into man-
ageable sub-units of action. Beyond the creation
of sub-tasks, delegation necessitates the assign-
ment of responsibility and authority (Mueller and
Vogelsmeier, 2013; Nagia, 2024) and thus impli-
cates accountability for outcomes. Delegation
thus involves risk assessment, which can be mod-
erated by trust (Griffiths, 2005). Delegation fur-
ther involves capability matching and continu-
ous performance monitoring, incorporating dy-
namic adjustments based on feedback, and ensur-
ing completion of the distributed task under the
specified constraints. Current approaches tend
to fail to account for these factors, relying more
on heuristics and/or simpler parallelization. This
may be sufficient for early prototypes, but real
world AI deployments need to move beyond ad
hoc, brittle, and untrustworthy delegation. There
is a pressing need for systems that can dynam-
ically adapt to changes (Acharya et al., 2025;
Hauptman et al., 2023) and recover from errors.
The absence of adaptive and robust deployment
frameworks remains one of the key limiting fac-
tors for AI applications in high-stakes environ-
ments.
To fully utilize AI agents, we needintelligent
delegation: a robust framework centered around
Corresponding author(s): nenadt@google.com
©2026 Google. All rights reserved
arXiv:2602.11865v1  [cs.AI]  12 Feb 2026