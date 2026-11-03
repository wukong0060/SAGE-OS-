# SAGE Operation Broker — Reference Alpha

**Status:** Executable reference implementation with CI tests  
**Scope:** Orchestration and contract behavior only; not yet integrated with the SAGE Windows application.

## 1. Files

- `src/Sage.Foundation.Contracts/OperationContracts.cs` — typed request, target, preview, approval, policy and result records plus host interfaces.
- `src/Sage.Foundation.Runtime/OperationBroker.cs` — compatibility → policy → preview → approval → journal → apply → verify → rollback orchestration.
- `Tests/Sage.Foundation.Runtime.Tests/Program.cs` — deterministic fake-host tests.
- `.github/workflows/sage-operation-broker.yml` — .NET 10 CI execution.

The runtime projects target .NET 10 and contain no Windows-specific API calls. This is deliberate: the broker should coordinate domain adapters without coupling its orchestration rules to WinUI or a particular Windows API.

## 2. Supported reference flows

### Read-only inspection

1. Require an `Inspect` action and `ReadOnly` mode.
2. Require a registered handler.
3. Require an explicit `Compatible` result. `Unknown` is not treated as compatible.
4. Ask the policy evaluator.
5. Invoke the handler's read-only inspection method.
6. Do not create a mutation journal.

### Mutating operation

1. Require a `Preview` action in `Mutating` mode.
2. Resolve compatibility and ask policy whether a preview may be shown.
3. Ask the feature handler to produce the planned changes.
4. Validate that the preview is bound to the exact operation ID, feature ID, target and compatibility snapshot.
5. Store the preview with an expiry.
6. For Apply, reload that preview and recheck compatibility. A changed capability snapshot invalidates it.
7. Verify that any supplied approval is bound to the exact operation, feature, target, preview hash, approved scope and expiry.
8. Re-evaluate policy against the current compatibility result, exact preview and approval proof.
9. Atomically consume the preview so it cannot be replayed.
10. Persist a prepared journal before invoking the mutating handler.
11. Execute, verify the intended resulting state, then commit.
12. If execution or verification fails, attempt compensation and record either `rolled_back` or `recovery_incomplete`.

## 3. Explicit safety boundaries

- The broker does not run PowerShell, shell commands, registry writes, service changes, driver changes, network configuration changes or file operations by itself.
- The broker cannot make an untrusted handler safe. Each handler needs a reviewed target allowlist, bounded inputs, capability requirements and independent tests.
- `IOperationJournal` and `IPreviewStore` are interfaces only. The test harness uses in-memory fakes. Production adapters must persist journals durably and implement atomic preview consumption across processes/restarts.
- `IPolicyEvaluator` and `IApprovalVerifier` are host-supplied. The reference code does not issue signed approvals or decide the risk tier itself.
- The feature's risk and required approval must come from a trusted capability/policy registry, not from caller-controlled `RiskTier` values.
- Preview hashes must be computed over a canonical serialization of the exact planned changes, target and relevant state. A preview that changes in any relevant way needs a new hash and approval.
- Approval proofs must be authenticated (for example, a signed, short-lived host-issued token). A plain in-memory record is not authentication.
- The journal adapter must be crash-safe, tamper-evident where appropriate, and capable of recovery after process termination or power loss.
- A failed rollback remains visible as `recovery_incomplete`; the broker must not claim success or silently continue.
- A checksum is not a signature; release trust is handled separately by F6.

## 4. Current limitations

This is an orchestration prototype, not a production-ready system-change engine. Before integration, it still needs:

1. A durable journal and single-use preview repository.
2. A trusted capability registry that resolves feature risk, supported lane, handler identity and required capabilities.
3. A central policy engine and cryptographically verifiable approval token service.
4. Canonical preview serialization and SHA-256 generation.
5. Operation idempotency, duplicate-operation protection and process-restart recovery.
6. Structured audit/evidence events and redacted user-visible operation history.
7. Controlled elevation and Windows PowerShell 5.1/7/native handler adapters.
8. Windows VM tests for interrupted apply, rollback, journal tampering and state conflicts.
9. Integration tests against the actual SAGE feature handlers.
10. Accessibility and UX flows for preview, approval and recovery status.

The current reference interfaces intentionally make those missing responsibilities visible rather than simulating them with an unsafe default implementation.

## 5. CI coverage

The .NET reference harness includes tests for:

- Read-only inspection without a mutation journal.
- Unknown compatibility failing closed.
- Policy denial blocking previews.
- Missing approval blocking mutation.
- Successful preview, approval, apply and verification.
- Verification failure triggering rollback.
- Unverified rollback remaining `recovery_incomplete`.
- Expired previews being rejected.
- Changed compatibility snapshots invalidating previews.
- Read-only apply requests being rejected.
- A successful preview being single-use.
- Approval bound to a different target being rejected.

These are reference-level tests with fake host services. They do not demonstrate Windows runtime behavior or a production journal.

## 6. Integration order

1. Reconcile the complete SAGE source tree.
2. Implement and validate the capability registry.
3. Implement durable preview and journal stores.
4. Implement policy and signed-approval services.
5. Add one low-risk, reversible SAGE-owned handler behind the broker.
6. Prove apply/verify/rollback and crash-recovery in disposable Windows VMs.
7. Migrate additional handlers one at a time, keeping old routes disabled until equivalence tests pass.

Do not let a suite call a mutating handler directly. The broker is intended to become the only mutation path after host adapters and production tests are complete.
