# Page 16

Intelligent AI Delegation
egator (the “verifier”) that a computation was
performed correctly on a dataset, without reveal-
ing the data itself. For example, an agent tasked
with analyzing a sensitive dataset can generate a
succinct non-interactive argument of knowledge
(zk-SNARK) (Bitansky et al., 2013; Petkus, 2019)
that proves a specific property of the result. The
delegator can verify this proof instantly, gaining
certainty of the outcome without ever viewing
the underlying sensitive data. Alternatively, ho-
momorphic encryption (Acar et al., 2018) and se-
cure multi-party computation (Goldreich, 1998;
Knott et al., 2021) allow for computation to be
performed on encrypted data. These methods
apply to task execution and monitoring alike: the
delegatee performs a pre-agreed monitoring func-
tion on the encrypted intermediate state, sending
the result to the delegator, who is the only party
capable of decrypting it to verify compliance.
The final axis is topology. Across complex net-
works that may arise in the agentic web, tasks
can be decomposed and re-delegated, forming a
delegation chain: Agent𝐴 delegates to𝐵, which
further sub-delegates a part of the task to𝐶, and
so on. This introduces the problem of achieving
effectivetransitive monitoring. In such delegation
chains, it may not be feasible for the original del-
egator (Agent𝐴in the example above) to directly
monitor agent𝐶, or to monitor𝐶 to the same ex-
tent to which it monitors𝐵. 𝐴 may have a smart
delegation contract with𝐵, and𝐵may have a con-
tract with𝐶, but unless𝐴 also contracts with𝐶,
those provisions may simply not be in place. For
other reasons,𝐵may not wish to expose its sup-
plier (𝐶) to its client (𝐴). Technically,𝐴, 𝐵, and𝐶
mayusedifferentmonitoringprotocols,andagree
on different monitoring levels, due to differences
in each agent’s reputation within the network.
There may be bespoke privacy concerns specific
to each individual delegation link. A more prac-
tical model is thereforetransitive accountability
via attestation. In this framework, Agent𝐵 moni-
tors its delegatee,𝐶. 𝐵then generates a summary
report of𝐶’s performance (e.g., “Sub-task_2 com-
pleted, quality score: 0.87, resources consumed:
5 GPU-hours”). 𝐵 then cryptographically signs
the report and forwards it to𝐴 embedded in its
own scheduled status update. Agent𝐴 does not
monitor𝐶directly, butinsteadmonitors 𝐵’sability
to monitor𝐶. For such delegated monitoring to
be effective, it requires𝐴to be able to trust in𝐵’s
verification capabilities, which can be ensured by
𝐵 having its monitoring processes certified by a
trusted third party.
4.6. Trust and Reputation
Trust and reputation mechanisms constitute the
foundation of scalable delegation, minimizing
transactional friction and promoting safety in
open multi-agent environments. We define trust
as the delegator’s degree of belief in a delegatee’s
capability to execute a task in alignment with ex-
plicit constraints and implicit intent. This belief
is dynamically formed and updated based on ver-
ifiable data streams collected via the monitoring
protocols described previously (see Section 4.5).
Reputation serves as a predictive signal, de-
rived from an aggregated and verifiable history of
past actions, which act as a proxy for an agent’s
latent reliability and alignment. We distinguish
reputation as the public, verifiable history of an
agent’sreliability,andtrustastheprivate,context-
dependent threshold set by a delegator. An agent
may have high overall reputation, yet fail to meet
the specific, contextual trust threshold required
for certain high-stakes task. Trust and reputation
allow a delegator to make informed decisions
when choosing delegatees, effectively governing
the autonomy granted to the agent, and the level
of oversight. Higher trust enables the delegator
to incur a lower monitoring and verification cost.
Reputation mechanisms can be implemented
in different ways (see Table 3). The most direct
approach is encoding it in a performance-based
immutable ledger. Here , each completed task
is recorded as a transaction containing verifiable
metrics: task completion success or failure, total
resource consumption (compute, time), adher-
ence to deadlines, adherence to constraints, and
the quality of the final output as judged by the
delegator. The immutability of the ledger would
prevent tampering with an agent’s history, provid-
ing a reliable foundation for its reputation. How-
ever, a naive implementation could be susceptible
to gaming. For example, an agent can inflate
its reputation by only accepting simple, low-risk
16