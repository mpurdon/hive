# Page 23

Intelligent AI Delegation
tion sub-steps are sent to human overseers too
frequently, overseers may eventually default to
heuristic approval, without deeper engagement
and appropriate checks. Therefore, friction must
be context-aware: the system should allow seam-
less execution for for tasks with low criticality
or low uncertainty, but dynamically increase cog-
nitive load, by requiring justification or manual
intervention when the system encounters higher
uncertainty or is faced with unanticipated scenar-
ios.
5.2. Accountability in Long Delegation Chains
In long delegation chains (𝑋→𝐴→𝐵→𝐶→
...→𝑌 ), the increased distance between the
original intent (𝑋) and the ultimate execution (𝑌)
may result in an accountability vacuum (Slota
etal.,2023). Presumingthat 𝑋isthehumanusers
in this example, specifying the task or the intent
that the corresponding personal AI assistant𝐴
acts upon, it may not be feasible (or reasonable)
to expect a human user to audit the𝑛-th degree
sub-delegatee in the execution graphs.
To address this, the framework may need to
implement liability firebreaks (Section 2), as pre-
defined contractual stop-gaps where an agent
must either:
1. Assume full, non-transitive liability for all
downstream actions, essentially “insuring”
the user against sub-agent failure.
2. Halt execution and request an updated trans-
fer of authority from the human principal.
Furthermore, the system must maintain im-
mutable provenance, ensuring that even if an
outcome is unintended, the chain of custody re-
garding who delegated what to whom remains
auditorially transparent.
Ensuring full clarity of each role and the ac-
countabilitythatitcarrieshelpslimitthediffusion
of responsibility, and prevents adverse outcomes
where systemic failure would not be possible to
attribute to any single node in the network.
5.3. Reliability and Efficiency
Implementing the proposed verification mecha-
nisms (ZKPs or multi-agent consensus games)
may introduce latency, and an additional compu-
tational cost, compared to unverified execution.
This constitutes a reliability premium, particu-
larly relevant for highly critical execution tasks.
On the other hand, there may be use cases where
this additional cost is unwarranted. One way
to address this in agentic markets would be to
support tiered service levels: low-cost delegation
for low-stakes routine tasks, and high-assurance
delegation for critical functions.
If high-assurance delegation is computationally
expensive, there is a risk that safety becomes a
luxury good. This poses an ethical issue: users
with fewer resources may be forced to rely on
unverifiedoroptimisticexecutionpaths, exposing
them to disproportionate risks of agent failure.
This should be mitigated by ensuring a level of
minimumviablereliability, asabaselinethatmust
be guaranteed for all users.
In competitive marketplaces, agents may pri-
oritize speed and low cost. Without additional
regulatory constraints, agents may therefore be
incentivized to avoid expensive safety checks to
outcompete other agents on price or latency. This
may introduce a level of systemic fragility. Gover-
nance layers must therefore enforce safety floors:
mandatory verification steps for specific classes of
tasks (e.g., financial transactions or health data
handling) that cannot be bypassed for the sake of
efficiency.
5.4. Social Intelligence
As agents integrate into hybrid teams, they func-
tion not only as tools but as teammates, and occa-
sionallyasmanagers(AshtonandFranklin,2022).
This requires a form ofsocial intelligencethat re-
spects the dignity of human labor. When an AI
agent acts as a delegator and a human as a dele-
gatee, the delegation framework needs to avoid
scenarios where people feel micromanaged by
algorithms, and where their contributions are not
valued or respected. This presumes that the dele-
gator (as well as collaborators) has the capability
to form mental models of each human delegatee,
23