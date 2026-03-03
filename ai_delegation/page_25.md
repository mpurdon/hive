# Page 25

Intelligent AI Delegation
minor inefficiencies by intentionally delegating
some tasks to humans that it wouldn’t have oth-
erwise, with a specific intent of maintaining their
skills. This would help us avoid the future in
which the human principal is able to delegate, but
not accurately judge the outcome. To enhance
adjudication, human experts can be required to
accompany their judgments with a detailed ra-
tionale or a pre-mortem of potential failure risks.
This would help keep human participants in task
delegation chains more cognitively engaged.
Furthermore, unchecked delegation threatens
the organizational apprenticeship pipeline. In
many domains, expertise is built through the
repetitive execution of more narrowly scoped
tasks. These tasks are precisely the ones that are
most likely to be offloaded to AI agents, at least
in the short term. If learning opportunities are
thereby fully automated, junior team members
would be deprived of the necessary experience to
develop deep strategic judgement, impacting the
oversight readiness of the future workforce.
To counter the erosion of learning, intelligent
delegation frameworks should be extended to
include some form of a developmental objective.
Rather than relying on more passive solutions like
humans shadowing AI agents during task execu-
tion, we should aim to develop curriculum-aware
task routing systems. Such systems should track
the skill progression of junior team members and
strategically allocate tasks that sit at the bound-
ary of their expanding skill set, within the zone
of proximal development. In such a system, AI
agents may co-execute tasks and provide tem-
plates and skeletons, progressively withdrawing
this support as the junior team members demon-
strate that they have acquired the desired level of
proficiency. These educational frameworks may
be further enriched by incorporating detailed
process-level monitoring streams of AI agent task
execution (Section 4.5), that would offer valuable
developmental insights.
6. Protocols
For intelligent task delegation to be implemented
in practice, it is important to consider how its
requirements map onto some of the more estab-
lished and recently introduced AI agent proto-
cols. Notable examples of these include MCP (An-
thropic, 2024; Microsoft, 2025), A2A (Google,
2025b), AP2 (Parikh and Surapaneni, 2025), and
UCP (Handa and Google Developers, 2026). As
new agentic protocols keep being introduced, the
discussion here is not meant to be comprehensive,
rather illustrative, and focused on these popular
protocols to showcase how they map onto our
proposed requirements, and serve as an exam-
ple for a more technical discussion on avenues
for future implementation. There may well be
other existing protocols out there that are better
tailored to the core of the proposal, as the exam-
ple protocols discussed below have been selected
based on their popularity.
MCP.MCP has been introduced to standardize
how AI models connect to external data and tools
via a client-host-server architecture (Anthropic,
2024; Microsoft, 2025). By establishing a uni-
form interface – using JSON-RPC messages over
stdioorHTTPSSE–itallowstheAImodel(client)
to interact consistently with external resources
(server). This reduces the transaction cost of del-
egation; a delegator does not need to know the
proprietary API schema of a sub-agent, only that
the sub-agent exposes a compliant MCP server.
Routingallinteractionsthroughthisstandardized
channel enables uniform logging of tool invoca-
tions, inputs, and outputs, facilitating black-box
monitoring. MCP defines capabilities but lacks
the policy layer to govern usage permissions or
support deep delegation chains. It provides bi-
nary access – granting callers full tool utility –
without native support for semantic attenuation,
such as restricting operations to specific read-only
scopes. Additionally, MCP is stateless regarding
internal reasoning, exposing only results rather
than intent or traces. Finally, the protocol is ag-
nostic to liability and lacks native mechanisms
for reputation or trust.
A2A.The A2A protocol serves as the peer-to-
peer transport layer on the agentic web (Google,
2025b). It defines how agents can discover peers
viaagent cardsand manage task lifecycles viatask
objects. The A2A agent card structure, a JSON-
LD manifest listing an agent’s capabilities, pric-
ing, and verifiers, may act as the foundational
25