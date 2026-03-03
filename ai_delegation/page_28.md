# Page 28

Intelligent AI Delegation
more interesting consequence of such an exten-
sion would be that it allows for easy restriction
chaining, which becomes relevant in long delega-
tion chains. Each participant in the chain could
add subsequent restrictions that correspond to
the requirements of the sub-delegation, further
limiting the scope and carving out the specific
role for sub-delegatees.
Adaptive coordination (Section4.4) would ben-
efit from the ability to easily swap delegatee
agents mid-task if the performance degrades be-
low a certain threshold, or in case of preemptions
or other possible environmental triggers. Having
a standard schema for checkpoint artifacts would
enable for the task to be resumed or restarted
with minimal overhead. This would enable the
delegatees and the delegators to serialize partial
work more easily. Agents would then be able to
periodically commit a state_snapshot to a shared
storage referenced in the A2A Task Object. This
wouldpreventtotalworkloss, whichwastesprevi-
ouslycommittedresources. Forthistobesensible,
it would need to be further coupled with explicit
clauses within the smart contract that enable par-
tial compensation, and verification of the task
completion percentage. As such, it may not be
applicable to all circumstances.
These are merely illustrative examples for the
kinds of functionalities that would be possible to
include in agentic protocols to unlock different
aspects of intelligent task delegation. As such,
they are neither comprehensive, nor meant as a
definitive proposal. The type of extension that is
required would also depend on the underlying
protocol being extended. We hope that these ex-
amples may provide the developers with some
initial ideas for what to explore in this space mov-
ing forward.
7. Conclusion
Significant components of the future global econ-
omy will likely be mediated by millions of special-
ized AI agents, embedded within firms, supply
chains, and public services, handling everything
from routine transactions to complex resource
allocation. However, the current paradigm of ad-
hoc, heuristic-based delegation is insufficient to
support this transformation. To safely unlock the
potential of the agentic web, we must adopt a
dynamic and adaptive framework forintelligent
delegation, that prioritizes verifiable robustness
and clear accountability alongside computational
efficiency.
WhenanAIagentisfacedwithacomplexobjec-
tive whose completion requires capabilities and
resources beyond its own means, this agent must
assume the role of a delegator within the intel-
ligent task delegation framework. This delega-
tor would subsequently decompose this complex
task into manageable subcomponents that can
be mapped onto the capabilities available on the
agentic market, at the level of granularity that
lends itself to high verifiability. The task alloca-
tion would be decided based on the incoming
bids, and a number of key considerations includ-
ing trust and reputation, monitoring of dynamic
operational states, cost, efficiency, and others.
Tasks with high criticality and low reversibility
may require further structured permissions and
tieredapprovals, withaclearstructureofaccount-
ability, and under appropriate human oversight
as defined by the applicable institutional frame-
works.
At web-scale, safety and accountability can-
not be an afterthought. They need to be baked
into the operational principles of virtual agentic
economies, and act as central organizing princi-
ples of the agentic web. By incorporating safety
at the level of delegation protocols, we would
be aiming to avoid cumulative errors and cas-
cading failures, and attain the ability to react
to malicious or misaligned agentic or human be-
havior rapidly, limiting the adverse consequences.
What we propose is ultimately a paradigm shift
from largely unsupervised automation to veri-
fiable, intelligent delegation, that allows us to
safely scale towards future autonomous agentic
systems, while keeping them closely tethered to
human intent and societal norms.
References
A. Acar, H. Aksu, A. S. Uluagac, and M. Conti. A
survey on homomorphic encryption schemes:
Theory and implementation.ACM Computing
28