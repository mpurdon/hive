# Page 27

Intelligent AI Delegation
For example, the A2A Task object may be ex-
tended to include fields that would incorporate
verification standards, making it possible to en-
force the previously discussedcontract-first de-
compositionat the protocol level. This is an im-
portant requirement for high-stakes delegation.
A pre-execution handshake would enable the del-
egator to define the evidence standard required
for the task to be considered valid.
"verification_policy": {
"mode": "strict",
"artifacts": [
{
"type":
"unit_test_log",
"validator":
"mcp://test-runner-agent",
"signature_required": true
},
{
"type":
"zk_snark_trace",
"circuit_hash":
"0xabc123...",
"proof_protocol":
"groth16"
}
],
"escrow_trigger": true
}
}
This forces the delegatee to simulate the ver-
ification step before accepting the task. If the
delegatee lacks the capability to generate a ZK-
proof, it must decline the bid during the matching
phase, preventing future downstream failures.
Detailed, process-level monitoring has been
discussed as one of the key considerations to help
safeguard task delegation in high-criticality tasks.
Given that monitoring protocols aren’t natively
supported in many of the existing protocols,
extensions that introduce monitoring capabilities
could be considered. For example, one could
considerextending aprotocol likeMCP toinclude
an additional monitoring stream. Such a stream
would log the agent’s internal control loop events
via Server-Sent Events. To address the privacy
constraints, the stream could be configurable
in a way that supports different levels of nego-
tiated granularity: L0_IS_OPERATIONAL,
L1_HIGH_LEVEL_PLAN_UPDATES,
L2_COT_TRACE, L3_FULL_STATE. Config-
urable granularity can also modulate cognitive
friction, as human overseers would be able to
subscribe to a specific stream.
Intelligent Delegation requires a market mech-
anism to trade off cost, speed, and privacy. This
could be implemented via a formal Request for
Quote (RFQ) protocol extension. Prior to task
assignment, the delegator would broadcasts a
Task_RFQ. Agents interested in acting as delega-
tees may then respond with signed Bid_Objects.
"bid_object": {
"agent_id":
"did:web:fast-coder.ai",
"estimated_cost":
"5.00 USDC",
"estimated_duration":
"300s",
"privacy_guarantee":
"tee_enclave_sgx",
"reputation_bond":
"0.50 USDC",
"expiry":
"2026-10-01T12:00:00Z"
}
Passing raw API keys or open MCP sessions to
sub-agents would violate the principle of least
privilege. To address this, it may be possible to
introduce Delegation Capability Tokens (DCT),
based on Macaroons (Birgisson et al., 2014) or
Biscuits (Couprie et al., 2026), as attenuated au-
thorization tokens (Sanabria and Vecino, 2025).
A delegator would then mint a DCT that wraps
thetargetresourcecredentialswithcryptographic
caveats. The attenuation could be defines as "This
token can access the designated Google Drive
MCP server, BUT ONLY for folder Project_X AND
ONLY for READ operations.". This token would
get invalidated in case the restrictions are not fol-
lowed, if a delegatee attempts to go beyond the
requested scope (in this example, however, access
permissions should also be directly managed). A
27