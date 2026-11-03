# SAGE Implementation Roadmap — 6 × 6 × 6

**Status:** Proposed execution order  
**Principle:** Integrate and verify the platform before expanding feature count.

## Release rule

Do not start broad feature expansion until the target source lineage is known and the six shared foundations have enforceable contracts. Each phase ends with a measurable exit gate; a phase is not complete merely because its UI page or script exists.

## Phase 0 — Source lineage and release baseline (P0)

**Goal:** Establish one reproducible source baseline for SAGE 3.8.0.

Work:
- Obtain the complete 3.8.0 source archive and exact checksum sidecar.
- Record archive SHA-256, Git commit, source branch, version metadata and source-parent lineage.
- Compare the archive with repository main and active feature branches; generate a file-level merge/rebase report.
- Identify which 3.6.x reports represent code actually present in 3.8.0 versus detached source passes.
- Freeze deployment lanes and publish one canonical support/capability matrix.

Exit gate:
- Archive integrity and checksum match.
- One documented source-of-truth commit/tag.
- No unresolved duplicate/conflicting release manifests.
- Every capability is mapped to a verified file/commit or explicitly marked report-only/unconfirmed.

## Phase 1 — Foundation contracts (P0)

**Goal:** Make the six foundations enforceable shared infrastructure.

Deliver:
1. Compatibility contract: capability IDs, OS/edition/build/architecture/hardware/API requirements, supported lane and reason codes.
2. Execution contract: typed request/result, adapter interface, structured logs, progress, cancellation, timeout, exit states and controlled elevation.
3. Policy contract: risk tiers, deny-by-default authorization, consent scope and central pre-execution enforcement.
4. State contract: transaction ID, snapshot reference, journal schema, verify/compensate interface, crash/interruption recovery and migrations.
5. Evidence contract: finding, measurement, provenance, confidence, benchmark, event and support-bundle schemas.
6. Trust contract: signed manifest, artifact hashes, signer identity, dependency inventory/SBOM, licensing and update provenance.

Exit gate:
- Contract tests cover success, denial, incompatible target, timeout, cancellation, executor failure, verification failure and recovery failure.
- Mutating operations cannot run without policy authorization and a valid operation envelope.
- Read-only operations are tested for write-free behavior.
- Missing/unknown capability data fails closed for risky features.

## Phase 2 — Core services (P1)

**Goal:** Make the six cores domain services that only depend on foundation contracts.

Suggested order:
- SAGE Core: process/service/startup/power/profile inventory and shared orchestration.
- SAGE Device: provider-based inventory and sensor abstractions; unavailable sensor fields remain null/unavailable.
- SAGE Network: adapter/route, DNS, TCP and user-initiated latency testing.
- SAGE Guardian: snapshots, journal catalog, recovery posture and compensating actions.
- SAGE Gaming: launcher/game inventory, profile model, session model and benchmark data.
- SAGE Intelligence: deterministic diagnostics, explanation, recommendation confidence and consent-gated AI summarization.

Exit gate:
- Each core has versioned APIs, domain tests and no direct references to suite view models.
- Cross-core composition is tested with mocked provider boundaries.
- No duplicated device/network/compatibility implementations remain in individual suites.

## Phase 3 — Six suites and clean ownership (P1)

**Goal:** Build six coherent user experiences over the core APIs.

- Control Center: home, optimizer, profiles, maintenance, diagnostics, Store and update status.
- Gaming Center: game library, profiles, session monitor, Latency Lab and Benchmark Lab.
- SAGE Studio: theme authoring, import/export, preview and supported appearance transactions.
- Desktop Experience: launcher, command palette, workspaces, tiling/window management, flyouts/widgets and shell recovery surfaces.
- Device & Network Center: hardware, drivers, sensors, storage, displays, battery, peripherals and network diagnostics.
- Guardian Center: security/privacy posture, change history, snapshots, recovery and support bundle.

Exit gate:
- No raw script execution from a page or suite.
- Each suite follows the same capability availability and operation-history model.
- Studio and Desktop Experience have separate ownership and contracts.
- Keyboard navigation, screen-reader labels, high contrast, scaling and reduced-motion behavior are tested before stable release.

## Phase 4 — Existing capability integration and consolidation (P1/P2)

**Goal:** Bring existing implementations into the six-core model without duplicating them.

Work:
- Map System Doctor, Network Intelligence and Guardian 3.8.0 source features to the new contracts.
- Reconcile Optimizer and Customization Studio report changes with the verified 3.8.0 source baseline.
- Migrate TEMP quarantine, theme apply and profile apply onto the common operation lifecycle.
- Move benchmark/PresentMon workflows to a unified Evidence record and history store.
- Replace duplicate SAGE-600/6200/7000/research lists with a normalized catalogue. Keep legacy IDs as aliases and preserve rejected/deprecated records.
- Unify AI provider settings and consent. AI remains explanatory/proposal-only until each specific tool is separately authorized.
- Remove placeholder pages, inert controls, hard-coded profile choices and generic Apply/Revert routes.

Exit gate:
- Each migrated feature has a feature ID, core owner, suite surface, risk tier, status and evidence record.
- Regression tests confirm previous rollback protections were preserved.
- No catalogue entry is executable unless it has an allowlisted operation adapter and passing compatibility/policy/evidence gates.

## Phase 5 — Device, gaming and desktop depth (P2)

**Goal:** Deliver differentiated capabilities once the platform contracts are reliable.

Priorities:
- Device provider model for CPU/GPU/RAM/storage, sensors, power, battery, display and drivers.
- Gaming session monitor with truthful FPS/frame-time sources, process identity and per-game evidence.
- Benchmark history and comparison with hardware/driver/game/profile provenance.
- Latency Lab combining local network measurements with game-session timing; clearly label that ICMP latency is not game-server latency.
- Desktop Experience launcher, command palette, workspaces, window layouts and flyouts with reliable native-shell fallback.
- Studio expansion for taskbar/Start/Explorer customization only where Windows support and rollback are proven.

Exit gate:
- No synthetic FPS, frame-time, latency, temperature, fan, clock or utilization values.
- Benchmark comparisons normalize for capture method and hardware/software identity.
- Shell features have a tested recovery route that returns control to the native Windows shell.

## Phase 6 — Trust, deployment and release hardening (P0 release gate)

**Goal:** Publish reliable, independently supportable delivery lanes.

Work:
- Build/publish per architecture on native Windows runners.
- Verify signatures, manifests, dependency baselines and artifact hashes before install/update.
- Implement staged updates with health checks and rollback; never auto-install a discovered third-party update without user approval.
- Test installation, upgrade, repair, uninstall and preservation of user state for each lane.
- Test snapshots and interrupted restore on disposable Windows VMs.
- Build and inspect APBX separately; do not equate source validation or ZIP creation with APBX readiness.
- Produce redacted support bundles and a reproducible release report.

Exit gate:
- Windows PowerShell 5.1/7 tests pass where scripts are supported.
- Native x64/ARM64 builds and client runtime tests pass for each declared target.
- Windows 10 legacy and Windows 11 modern lanes pass their own install/upgrade/uninstall/recovery matrices.
- APBX build/install/upgrade/uninstall tests pass on supported Windows 11 targets.
- Signed release artifacts and published checksums verify.
- Production readiness flags reflect actually completed gates, never static-only checks.

## Priority order at a glance

| Priority | Workstream | Why it comes here |
|---|---|---|
| P0 | Source lineage + capability registry | Prevents merging the wrong tree and claiming features absent from the release. |
| P0 | Operation broker + policy/state contracts | Prevents UI-only security and inconsistent mutation/rollback paths. |
| P1 | Six core service APIs | Makes feature ownership clear and removes duplicate domain logic. |
| P1 | Six suite experiences | Converts domain services into consistent user workflows. |
| P1/P2 | Migration and catalogue consolidation | Integrates existing work and removes duplicate/unsafe entries. |
| P2 | Sensor/gaming/desktop depth | Builds SAGE's differentiators after the platform is reliable. |
| Release gate | Trust, Windows validation and APBX | Establishes honest production readiness. |

## Definition of done for every feature

A feature is not done when it merely appears in the UI. It is done when it has:
- One owner and stable feature ID.
- A capability/compatibility declaration.
- A policy and risk classification.
- A versioned operation contract.
- Preview and approval behavior appropriate to its risk.
- State journal and tested compensation for mutations.
- Structured evidence and useful error states.
- Accessibility and localization review.
- Automated tests plus target-Windows runtime validation.
- Documentation, release notes and supported-lane declaration.
