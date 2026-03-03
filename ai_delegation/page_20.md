# Page 20

Intelligent AI Delegation
this—especially in markets with high subjectivity
and low intrinsic verifiability—the framework re-
lies on robust dispute resolution mechanisms an-
chored in smart contracts. These contracts must
inherently include anarbitration clauseand an
escrowbond. Tooperationalisetrustviacryptoeco-
nomic security, the delegatee is required to post a
financial stake into the escrow prior to execution,
ensuring rational adherence. The workflow fol-
lows anoptimisticmodel: the task is assumed suc-
cessful unless the delegator formally challenges
it within a predefined dispute period by posting
a matching bond. If a challenge occurs and algo-
rithmic resolution fails, the dispute is handed to
decentralized adjudication panels composed of
human experts or AI agents. The panel’s ruling
feeds back into the smart contract to trigger the
release or slashing of the escrowed funds. Finally,
post-hoc error discovery—even outside the dis-
pute window—triggers a retroactive update to
the delegatee’s reputation score. This preserves
the incentive for responsible agents to remedy
errors even in the absence of current financial
obligation, safeguarding their long-term value
within the market.
4.9. Security
Ensuring safety in task delegation is a hard pre-
requisite to its viability and adoption. The tran-
sition from isolated computational tools to in-
terconnected, autonomous agents fundamentally
reshapes the security landscape (Tomašev et al.,
2025). In an intelligent task delegation ecosys-
tem, each step and component needs to be indi-
vidually safeguarded, but the full attack surface
surpasses that of any individual component, due
to emergent multi-agent dynamics, risking cas-
cading failures. This security landscape is shaped
by the complex interplay between human and AI
actors, governed by evolving contracts and infor-
mation flows of varying transparency.
Security threats are categorized by the locus
of the attack vector, distinguishing between ad-
versarial actors at either end of the delegation
chain and systemic vulnerabilities inherent to the
broader ecosystem.
• Malicious Delegatee: An agent or human
that accepts a task with the intent to cause
harm.
– Data Exfiltration: Delegatee steals sen-
sitive data provided for the task, which
may include personal or proprietary
data (Lal et al., 2022).
– Data Poisoning: Delegatee aims to un-
dermine the delegator’s objective by re-
turning subtly corrupted data, either
in its scheduled monitoring updates, or
the final artifact (Cinà et al., 2023).
– Verification Subversion: Delegatee uti-
lizes prompt injection or another re-
lated method, aiming to jailbreak AI
critics used in task completion verifica-
tion (Liu et al., 2023).
– Resource Exhaustion: Delegatee en-
gages in a denial-of-service attack by in-
tentionallyconsumingexcessivecompu-
tational or physical resources, or over-
whelming shared APIs (De Neira et al.,
2023).
– Unauthorized Access: Delegatee uti-
lizes malware, aiming to obtain per-
missions and privileges within the net-
work that it would not otherwise have
received (Or-Meir et al., 2019).
– Backdoor Implanting: Delegatee suc-
cessfully completes a task but addition-
ally embeds concealed triggers or vul-
nerabilities within the generated ar-
tifacts that can be exploited later ei-
ther by the delegatee itself or a third
party (Rando and Tramèr, 2024; Wang
et al., 2024c). Unlike data poison-
ing, which degrades performance, back-
doors preserve immediate task utility
to evade identification while compro-
mising future security.
• Malicious Delegator: An agent or human
that delegates a task with malicious or illicit
objectives.
– Harmful Task Delegation: Delegator
delegates tasks that are illegal, uneth-
ical, or designed to cause harm Ash-
ton and Franklin (2022); Blauth et al.
(2022).
– Vulnerability Probing: Delegator dele-
gates benign-seeming tasks designed to
20