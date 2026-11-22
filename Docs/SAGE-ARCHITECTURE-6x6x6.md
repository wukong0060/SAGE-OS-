# SAGE Architecture RFC — 6 × 6 × 6

**Status:** Draft architecture standard  
**Target:** SAGE OS 3.8.x and forward  
**Decision:** Six shared foundations, six service cores, six user-facing suites  
**Important:** This RFC defines the target architecture. It does not claim every listed subsystem has already been implemented or integrated.

## 1. Product boundary

SAGE is a Windows optimization, customization, gaming-performance and system-management platform with a Control Center and a separate Windows playbook/deployment path. It is not a separately bootable operating system.

Keep three delivery lanes explicit and independently testable:

1. **Standalone Control Center:** the desktop application and its supported capabilities.
2. **Legacy companion:** a deliberately narrower compatibility/runtime lane where required; it must not inherit unsupported modern-shell features.
3. **AME/APBX playbook:** Windows configuration and deployment workflows, with its own build, installation, upgrade, uninstall and recovery gates.

A capability is not supported merely because a related script, UI page, playbook task or catalogue record exists.

## 2. The six foundations

Foundations are shared platform services. Every core consumes them through stable contracts; suites never bypass them to invoke raw scripts or perform privileged writes.

| ID | Foundation | Owns |
|---|---|---|
| F1 | **Compatibility Foundation** | Windows edition/build/architecture detection; hardware, firmware, driver and API capability inventory; deployment-lane rules; feature gates; compatibility reasons. |
| F2 | **Execution Foundation** | Typed operation contracts; PowerShell 5.1/7 and native adapters; process lifecycle; structured output; progress; cancellation; timeout; controlled elevation. |
| F3 | **Policy Foundation** | Deny-by-default policy; operation risk tiers; permission scopes; user approval; consent; capability authorization; policy evaluation at the execution boundary. |
| F4 | **State Foundation** | Snapshots; transaction journals; state ownership; schema migrations; verification; compensating actions; interrupted-operation recovery. |
| F5 | **Evidence Foundation** | Structured findings; telemetry; logs; provenance; confidence; benchmark capture/history; diagnostic export and redaction. |
| F6 | **Trust Foundation** | Signed release/catalog manifests; artifact and dependency verification; SBOM/licensing; installer/update trust; provenance; repair and uninstall integrity. |

### Foundation rules

- Compatibility is evaluated before a feature is offered and again before an operation executes.
- Policy is enforced by the operation broker, not only by disabled buttons in the UI.
- Every mutating operation declares its risk, scope, preview, approval requirement, state strategy, verification and rollback/compensation behavior.
- Read-only operations declare and test their read-only boundary.
- Evidence distinguishes observed facts from inferred causes and recommendations.
- Trust checks fail closed when signatures, hashes, manifests or provenance are missing or invalid.
- No foundation silently changes Windows configuration.

## 3. The six service cores

Cores own domain logic and APIs. They do not own suite navigation, page layout or direct UI event handling.

| ID | Core | Owns |
|---|---|---|
| C1 | **SAGE Core** | Windows and resource management; processes, services and startup inventory; power and system profiles; settings; maintenance orchestration; shared operation coordination. |
| C2 | **SAGE Gaming** | Game and launcher discovery; game library; per-game profiles; session tracking; frame-time/FPS integration; benchmark workflows; game-specific evidence. |
| C3 | **SAGE Intelligence** | Deterministic diagnostics; analytics; recommendations; AI provider abstraction; explanation and report synthesis; recommendation confidence and provenance. |
| C4 | **SAGE Guardian** | Security/privacy posture; SAGE state integrity; snapshots; recovery readiness; transaction/journal audit; rollback coordination. |
| C5 | **SAGE Device** | CPU/GPU/RAM/storage inventory; sensors when exposed; clocks/temperature/power/fan data where supported; drivers; displays; battery; peripherals. |
| C6 | **SAGE Network** | Adapters; routes; Wi-Fi/Ethernet; DNS; TCP/IP; connectivity probes; latency, jitter and loss; network configuration and evidence. |

### Core boundaries

- SAGE Core is the general Windows domain, not a bucket for every feature.
- Gaming consumes device and network telemetry but does not own hardware or network discovery.
- Intelligence recommends and explains; it does not become an unrestricted system executor.
- Guardian coordinates recovery and protects SAGE-owned state; it is not a replacement for Windows recovery or a general disk-imaging tool.
- Device and Network remain separate cores even though one suite presents them together.
- Sensor or driver values that are unavailable must be reported as unavailable, never fabricated.

## 4. The six user-facing suites

Suites are product experiences. They compose core services and foundations through supported APIs.

| ID | Suite | Owns |
|---|---|---|
| S1 | **SAGE Control Center** | Home/dashboard; system profiles and settings; optimizer; maintenance; diagnostics entry point; Store; update status. |
| S2 | **SAGE Gaming Center** | Game library; launcher integration; per-game profiles; session view; performance overlay entry points; benchmark lab. |
| S3 | **SAGE Studio** | Appearance and theme creation; theme import/export; wallpaper; supported personalization; preview and apply experience. |
| S4 | **SAGE Desktop Experience** | Runtime desktop interaction: launcher, command palette, workspaces, window tiling/management, flyouts, widgets, status surfaces, multi-monitor behavior. |
| S5 | **SAGE Device & Network Center** | Hardware inventory/monitoring; drivers; peripherals; storage; battery; displays; Wi-Fi/Ethernet; network diagnostics. |
| S6 | **SAGE Guardian Center** | Security/privacy posture; protection status; change history; snapshots; recovery readiness; rollback and support evidence. |

### Preventing suite overlap

- **Studio creates and manages appearance.** It owns themes, wallpaper, personalization presets and their preview/apply/import/export workflow.
- **Desktop Experience runs interaction surfaces.** It owns launcher, command palette, workspaces, window management, flyouts/widgets and desktop interaction behavior.
- Studio may publish an approved theme consumed by Desktop Experience, but it does not own the shell runtime.
- Control Center is the general management entry point. Store and Update Center are modules within it, not separate top-level suites.
- AI Assistant is a cross-suite capability powered by Intelligence, not a seventh suite.
- Latency Lab is a Gaming Center workflow that consumes Network and Gaming core data.
- Benchmark Lab is a Gaming Center workflow backed by Gaming and Evidence services.

## 5. Suite-to-core composition

| Suite | Primary core | Supporting cores | Main foundation use |
|---|---|---|---|
| Control Center | SAGE Core | Intelligence, Guardian, Device | All six |
| Gaming Center | SAGE Gaming | Device, Network, Intelligence | All six |
| SAGE Studio | SAGE Core | Device, Guardian | Compatibility, Policy, Execution, State, Evidence, Trust |
| Desktop Experience | SAGE Core | Device, Guardian, Intelligence | All six |
| Device & Network Center | SAGE Device | Network, Intelligence, Guardian | All six |
| Guardian Center | SAGE Guardian | SAGE Core, Intelligence | All six |

All six foundations are shared by all six cores. The table names dominant dependencies for each suite; it is not permission to bypass other foundations.

## 6. Canonical operation lifecycle

Every feature that changes machine or user state uses the same operation lifecycle:

**Discover → CheckCompatibility → EvaluatePolicy → Preview → Approve → PrepareState → Execute → Verify → Commit**

Failure path:

**Execute/Verify failure → Compensate or RollBack → VerifyRecovery → RecordEvidence**

An operation record carries at least:

- operationId, featureId, coreId, suiteId, version and correlation/parent IDs.
- Target resource and scope; required capabilities; compatibility decision and reasons.
- Risk tier; policy decision; approval identity/time/scope; consent record where applicable.
- Preview summary and exact planned changes.
- State snapshot/journal reference; executor adapter; timeout and cancellation policy.
- Start/end timestamps; structured result/error code; verification result.
- Compensation/rollback result; evidence references; final state.

Recommended states: discovered, incompatible, denied, previewed, awaiting_approval, prepared, running, verifying, succeeded, failed, rollback_required, rolled_back, recovery_incomplete and cancelled.

Read-only diagnostics and inventory may omit snapshot/approval where policy says no mutation occurs, but their read-only contract must be explicit and tested.

## 7. Canonical feature placement

| Capability | Owning core(s) | Primary suite | Supporting suite(s) |
|---|---|---|---|
| Optimizer and system profiles | SAGE Core, Device, Intelligence | Control Center | Gaming Center |
| System Doctor | Intelligence, Guardian, Device | Control Center | Guardian Center |
| Network Intelligence | Network, Intelligence, Device | Device & Network Center | Control Center, Gaming Center |
| Guardian snapshots/recovery | Guardian, SAGE Core | Guardian Center | Control Center |
| Hardware Monitor | Device | Device & Network Center | Control Center, Gaming Center |
| Game library and per-game profiles | Gaming, Device | Gaming Center | Control Center |
| Latency Lab | Gaming, Network | Gaming Center | Device & Network Center |
| Benchmark Lab / PresentMon analysis | Gaming, Evidence Foundation | Gaming Center | Control Center |
| Customization Studio | SAGE Core, Device, Guardian | SAGE Studio | Control Center |
| Launcher/flyouts/workspaces | SAGE Core, Device, Guardian | Desktop Experience | Control Center |
| AI Assistant | Intelligence | Cross-suite surface | All suites |
| Store / Update Center | SAGE Core, Trust Foundation | Control Center | — |
| Support bundle | Intelligence, Guardian, Evidence Foundation | Guardian Center | Control Center |

## 8. Feature maturity and evidence model

Use exactly one primary state per capability:

- **implemented_source_reported:** an implementation report describes the feature; native Windows runtime validation is separate.
- **partial:** a limited implementation exists, with explicit gaps.
- **catalog_only:** records or research exist; the records are not executable optimizations.
- **proposal_only:** documented concept or recommendation; no operational implementation is claimed.
- **planned:** accepted for the roadmap, not implemented.
- **excluded:** intentionally not supported.
- **blocked:** prevented by an unresolved dependency, policy, compatibility or lineage issue.
- **lineage_unresolved:** report evidence exists, but integration into the target source tree is unverified.

Track validation separately from maturity: static_validated, windows_ps51_validated, windows_ps7_validated, native_build_validated, windows10_runtime_validated, windows11_runtime_validated, restore_recovery_validated and apbx_validated.

Never turn a static validation result into a claim of native runtime readiness.

## 9. Architecture acceptance criteria

1. Every shipped feature has one canonical featureId, owning core, primary suite, maturity state, supported capability set and validation record.
2. No suite invokes a raw script or performs privileged writes outside the Execution and Policy Foundations.
3. Mutating features have preview, explicit approval where required, journal/state strategy, verification and tested compensation.
4. Read-only features have tests proving that they do not write, migrate, install or alter configuration.
5. The six foundations expose versioned contracts and have contract tests.
6. Core services do not depend on suite view-model types.
7. Studio and Desktop Experience have distinct APIs and ownership boundaries.
8. Catalogues distinguish executable, proposal-only, research, deprecated and rejected records.
9. All deployment lanes have independent support matrices and release gates.
10. Release artifacts have verified provenance and trust metadata; no release is marked production-ready solely because static validation passed.

## 10. Source and lineage note

This RFC was prepared from available SAGE implementation and audit reports, including the 3.8.0 System Doctor/Network Intelligence/Guardian report and earlier Optimizer, Customization Studio, capability-matrix and gap-audit material. The complete 3.8.0 source ZIP was not present in the available Library at the time of writing; only its report and SHA-256 sidecar were available. This is a report-backed target map, not a file-by-file source audit of the full 3.8.0 tree.

The connected GitHub repository default branch also contains older 3.6.x lineage. This RFC is isolated on its own branch and must not be merged as though that repository were already the complete 3.8.0 source tree.

## References used

- SAGE-OS-v3.8.0-system-doctor-network-guardian-report.md
- SAGE-OS-v3.6.8-Customization-Studio-Implementation-Report.md
- SAGE-OS-v3.6.4-Optimizer-Suite-Implementation-Report.md
- SAGE-OS-v3.6.3-comprehensive-gap-audit.md
- SAGE-OS-v3.6.3-capability-matrix.md
- SAGE-OS-v3.6.3-platform-support-release-report.md
