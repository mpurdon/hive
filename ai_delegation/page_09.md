# Page 9

Intelligent AI Delegation
Table 1|The Intelligent Delegation Framework: Mapping requirements to technical protocols.
Framework Pillar Core Requirement Technical Implementation
Dynamic AssessmentGranular inference of agent state Task Decomposition (§4.1)
Task Assignment (§4.2)
Adaptive ExecutionHandling context shifts Adaptive Coordination (§4.4)
Structural TransparencyAuditability of process and outcome Monitoring (§4.5)
Verifiable Completion (§4.8)
Scalable MarketEfficient, trusted coordination Trust & Reputation (§4.6)
Multi-objective Optimization (§4.3)
Systemic ResiliencePreventing systemic failures Security (§4.9)
Permission Handling (§4.7)
uponhavingagreedonthestructureofthedecom-
position. These responsibilities are inextricably
linked; thedelegatorwilllikelyexecutebothfunc-
tions to facilitate dynamic recovery from latency,
pre-emption, and execution anomalies.
Decomposition should optimise the task execu-
tion graph for efficiency and modularity, distin-
guishing it from simple objective fragmentation.
This process entails a systematic evaluation of the
task attributes defined in Section 2 – specifically
criticality, complexity, and resource constraints –
to determine the suitability of sub-tasks for par-
allel versus sequential execution. Furthermore,
these attributes inform the matching of tasks to
corresponding delegatee capabilities. Prioritis-
ing modularity facilitates more precise matching,
as sub-tasks requiring narrow, specific capabil-
ities are matched more reliably than generalist
requests (Khattab et al., 2023). Consequently, the
decomposition logic functions to maximise the
probability of reliable task completion by align-
ing sub-task granularity with available market
specialisations.
To promote safety, the framework incorporates
“contract-first decomposition” as a binding con-
straint, wherein task delegation is contingent
upon the outcome having precise verification. If a
sub-task’s output is too subjective, costly, or com-
plex to verify (seeVerifiabilityin Section 4.2), the
system should recursively decompose it further.
The decomposition logic should maximise the
probability of reliable task completion by aligning
sub-task granularity (Section 2) with available
marketspecialisations. Thisprocesscontinuesfur-
ther until the resulting units of work match the
specific verification capabilities, such as formal
proofs or automated unit tests, of the available
delegatees.
Decomposition strategies should explicitly ac-
count for hybrid human-AI markets. Delegators
need to decide if sub-tasks require human inter-
vention, whether due to AI agent unreliability, un-
availability, or domain-specific requirements for
human-in-the-loop oversight. Given that humans
and AI agents operate at different speeds, and
withdifferentassociatedcosts, thestratificationis
non-trivial, as it introduces latency and cost asym-
metries into the execution graph. The decompo-
sition engine must therefore balance the speed
and low cost of AI agents against domain-specific
necessities of human judgement, effectively mark-
ing specific nodes for human allocation.
A delegator implementing an intelligent ap-
proach to task decomposition, may need to iter-
atively generate several proposals for the final
decomposition, and match each proposal to the
available delegatees on the market, and obtain
concrete estimates for the success rate, cost, and
duration. Alternative proposals should be kept
in-context, in case adaptive re-adjustments are
needed later due to changes in circumstances.
Upon selecting a proposal, the delegator must
formalise the request beyond simple input-output
pairs. Thefinalspecificationmustexplicitlydefine
roles, resourceboundaries, progressreportingfre-
quency, and the specific certifications required to
9