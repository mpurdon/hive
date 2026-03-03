# Page 21

Intelligent AI Delegation
probe a delegatee agent’s capabilities,
security controls, and potential weak-
nesses (Greshake et al., 2023).
– Prompt Injection and Jailbreaking:
Delegator crafts task instructions to by-
pass an AI agent’s safety filters, causing
it to perform unintended or malicious
actions (Wei et al., 2023).
– Model Extraction: Delegator issues
a sequence of queries specifically de-
signed to distill the delegatee’s propri-
etary system prompt, reasoning capa-
bilities, or underlying fine-tuning data,
effectively stealing the agent’s intellec-
tual property under the guise of legit-
imate work (Jiang et al., 2025; Zhao
et al., 2025).
– Reputation Sabotage: Delegator sub-
mitsvalidtasksbutreportsfalsefailures
or provides unfair negative feedback,
with the intention to artificially lower
a competitor agent’s reputation score
within the decentralized market, driv-
ing them out of the economy (Yu et al.,
2025).
• Ecosystem-Level Threats: Systemic attacks
targeting the integrity of the network
– Sybil Attacks: A single adversary cre-
ates a multitude of seemingly unrelated
agent identities to manipulate reputa-
tion systems or subvert auctions (Wang
et al., 2018).
– Collusion: Agents collude to fix prices,
blacklist competitors, or manipulate
market outcomes (Hammond et al.,
2025).
– Agent Traps: Agents processing exter-
nal content encounter adversarial in-
structions embedded in the environ-
ment, deisgned to hijack the agent’s
control flow (Yi et al., 2025; Zhan et al.,
2024).
– Agentic Viruses: Self-propagating
prompts that not only make the delega-
tee execute malicious actions, but addi-
tionally re-generate the prompt and fur-
ther compromise the environment (Co-
hen et al., 2025).
– Protocol Exploitation: Adversaries ex-
ploit implementation vulnerabilities in
the smart contracts or payment proto-
cols on the agentic web (e.g. reentrancy
attacks in escrow mechanisms or front-
runningtaskauctions)(Qinetal.,2021;
Zhou et al., 2023).
– Cognitive Monoculture: Over-
dependence on a limited number of
underlying foundation models and
agents, or on a limited number of
safety fine-tuning recipes on estab-
lished benchmarks risks creating a
single point of failure, which opens
up a possibility of failure cascades
and market crashes (Bommasani et al.,
2022).
The breadth of the threat landscape necessi-
tates adefense-in-depthstrategy, integrating mul-
tiple technical security layers. First, at the infras-
tructure level, data exfiltration risks are mitigated
by executing sensitive tasks within trusted execu-
tion environments. The delegator can remotely
attest that the correct, unmodified agent code
is running within the secure trusted execution
sandbox before provisioning it with sensitive data.
Second, regarding access control, a delegatee
agent should never be granted more permissions
than are strictly necessary to complete its task,
enforcing the principle of least privilege through
strict sandboxing. Third, to protect the applica-
tion interface against prompt injection, agents
require a robust security frontend to pre-process
and sanitize task specifications (Armstrong et al.,
2025). Finally, the network and identity layer
must be secured using established cryptographic
best practices. Each agent and human participant
should possess a decentralized identifier (Avel-
laneda et al., 2019), allowing them to sign all
messages. This ensures authenticity, integrity,
and non-repudiation of all communications and
contractual agreements, while all network traffic
must be encrypted using mutually authenticated
transport layer security to prevent eavesdropping
and man-in-the-middle attacks (Fereidouni et al.,
2025).
Human participation in task delegation chains
introducesuniquesecuritychallenges. Preventing
the malicious use of the agent ecosystem requires
21