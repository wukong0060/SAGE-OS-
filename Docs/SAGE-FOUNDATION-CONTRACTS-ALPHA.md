# SAGE Foundation Contracts — Alpha 1.0

These schemas make the six foundations concrete without coupling them to the older 3.6.x runtime tree. They are **contract drafts**, not yet adopted by runtime code.

| Foundation | Contract | Purpose |
|---|---|---|
| F1 Compatibility | Capability Descriptor | Feature availability, owners, deployment lanes and validation status |
| F2 Execution | Operation Request | Typed request envelope; explicitly not authorization |
| F3 Policy | Policy Decision | Central allow/deny/approval decision with reasons |
| F4 State | Transaction Journal | Durable state, step progress, recovery and rollback references |
| F5 Evidence | Evidence Record | Provenance, observations, recommendations, benchmark context and privacy |
| F6 Trust | Release Trust Manifest | Artifact hashes, source commit, signer, dependencies and SBOM reference |

## Mandatory invariants

1. **A request is not permission.** An operation request can be submitted, but the broker must obtain a fresh compatibility result and policy decision before any mutation.
2. **No UI-only policy.** The broker/executor enforces the policy decision even if a caller bypasses or tampers with UI state.
3. **Preview before mutation.** Mutating operations produce a preview bound to the target and relevant current state. Any target/state change invalidates the preview.
4. **Journal before change.** Persist the transaction and prepared step before the corresponding state mutation.
5. **Verify before commit.** A command exit code is not proof that the intended state was achieved.
6. **Compensation is explicit.** Each mutating operation declares a rollback or compensation strategy. Recovery-incomplete must remain visible if compensation cannot be verified.
7. **Evidence separates observation from inference.** Never label a recommendation or inferred cause as a measured fact.
8. **No invented telemetry.** Unavailable sensors/metrics are null or unavailable, not estimated silently.
9. **Trust is independently checked.** A checksum detects mismatch but is not a digital signature. Signed manifest verification, signer validation and source provenance are separate release gates.
10. **Deployment lanes are independent.** A capability descriptor names the lane(s) where it is supported; no feature inherits support by association.

## Versioning

- Schema contract versions are independent from SAGE application versions.
- Additive optional fields may be introduced in a minor schema revision.
- Removing or redefining a required field, enum meaning or state transition requires a breaking schema revision.
- Readers reject unsupported major versions and fail closed on unknown privileged-operation states.
- Every persisted record includes its schemaVersion or contractVersion and has an explicit migration path before a breaking update.

## Runtime integration order

1. F1 capability registry: read the descriptor before surfacing a capability and recheck at execution time.
2. F2 operation envelope: route all page-originated commands through one broker.
3. F3 policy decision: authorize the exact operation, target, scope and preview hash.
4. F4 transaction journal: prepare, execute, verify and compensate using one journal contract.
5. F5 evidence records: attach operation IDs and provenance to diagnostics, telemetry and benchmarks.
6. F6 trust manifest: verify release artifacts and dependencies before install, update or repair.

## Scope and validation limits

The schemas were designed as a shared contract layer. They have not yet been used by the SAGE application, PowerShell modules or AME playbook. Static contract checks do not prove Windows PowerShell behavior, native builds, runtime enforcement, recovery reliability or signed-release operation. Those need integration and Windows CI/VM tests against the reconciled source tree.
