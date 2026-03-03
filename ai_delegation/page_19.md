# Page 19

Intelligent AI Delegation
granularity be tailoreda priorito match avail-
able verification capabilities, ensuring that every
delegated objective is inherently verifiable.
Verification mechanisms within the framework
can be broadly categorized into direct outcome
inspection, trusted third-party auditing, crypto-
graphic proofs, and game-theoretic consensus.
First, direct outcome verification is feasible when
the delegator possesses the capability, tools, and
authority to directly evaluate the final outcome,
specifically for tasks with high intrinsic verifia-
bility and low subjectivity. This applies to auto-
verifiable domains (Li et al., 2024a) such as code
generation.4 Direct verification requires that the
outcome be sufficiently transparent, available,
and not prohibitively complex. Second, in sce-
narios where the delegator lacks the expertise
or permissions to access these artifacts, and tool-
based solutions are infeasible, verification can be
outsourced to a trusted third party. This could
be a specialized auditing agent, a certified hu-
man expert, or a panel of adjudicators. Third,
cryptographic verification represents a further op-
tion for trustless, automated verification in open
and potentially adversarial environments. It of-
fers mathematical certainty of correctness with-
out necessarily revealing sensitive information. A
delegatee can prove that a specific program was
executed correctly on a given input to produce a
certain output via techniques like zk-SNARKs. Fi-
nally, game-theoretic mechanisms can be used to
achieve consensus on an outcome. Several agents
may play a verification game (Teutsch and Re-
itwießner, 2024), with the reward distributed to
those producing the majority result—a Schelling
point (Pastine and Pastine, 2017). This approach,
inspiredbyprotocolslikeTrueBit(TeutschandRe-
itwießner, 2018), leverages economic incentives
to de-risk against incorrect or malicious results.
Such mechanisms may be particularly relevant
in rendering LLM-based verification of complex
tasks more robust.
Once a delegator marks the sub-task as ver-
ified, it issues a cryptographically signed veri-
fiable credential to the delegatee, serving as a
4This is the case when there is a corresponding set of test
cases that can be used to verify the implemented function-
ality.
non-repudiable receipt attesting that “Agent𝐴
certifies that Agent𝐵successfully completed Task
𝑇 on Date𝐷 to Specification𝑆.” This credential
is then incorporated into a permanent, verifiable
log of𝐵’s reputation within the market. Smart
contracts play a key role in finalizing the delega-
tion between agents, as they hold the payment in
escrow. A verification clause specifies the condi-
tions under which the funds are released, upon
receipt of the signed message of approval by the
delegator or an authorized third party. Once the
payment is executed, it constitutes an immutable
transaction on the blockchain.
In a delegation chain𝐴→𝐵→𝐶 , verifica-
tion and liability become recursive. Agent𝐴does
not have a direct contractual relationship with𝐶;
therefore, 𝐴cannot directly verify or hold𝐶liable.
The burden of verification and the assumption of
liability flow up the chain. Agent𝐵is responsible
for verifying the sub-task completed by𝐶. Upon
successful verification,𝐵 obtains proof from𝐶. 𝐵
then integrates𝐶’s result into its own workflow
towards completing the task it has been assigned.
When 𝐵 submits its final artifact to𝐴, it also sub-
mits the full chain of attestations.𝐴’s verification
process thus involves two stages: 1) verifying
the work performed directly by𝐵; and 2) ver-
ifying that 𝐵 has correctly verified the work of
its own sub-delegatee𝐶 by checking the signed
attestation from𝐶 that 𝐵 provides. Longer del-
egation chains or tree-like delegation networks
require a similarly recursive approach across mul-
tiple verification stages. Responsibility in delega-
tion chains is transitive and follows the individual
branches. Agents are accountable for the totality
of the tasks they have been granted and cannot
absolve themselves of accountability by blaming
subcontractors. Liabilityisderivedfromthechain
of contracts. For example, should𝐴 suffer a loss
duetoafailureoriginatingfrom 𝐶’swork, 𝐴holds
𝐵liable according to their direct agreement.𝐵, in
turn, seeks recourse from𝐶 based on their agree-
ment.
However, verification processes are not infalli-
ble. Subjectivetasks(Gunjaletal.,2025)canlead
to disagreements even when precise rubrics are
used, and errors may only be discovered long
after a task is marked complete. To address
19