# SAGE 3.8.0 — Report-backed Capability Map

**Status:** Architecture mapping draft; not a source-tree audit  
**Mapping target:** 6 foundations × 6 cores × 6 suites  
**Confidence rule:** A feature is called implemented only where an implementation report says it was delivered. Runtime/build validation is a separate field.

## 1. Executive summary

The reports describe meaningful source-level implementations across diagnostics, network testing, Guardian/recovery posture, optimizer workflows, gaming inventory/telemetry and customization. They also document gaps in central orchestration, feature-state truth, runtime validation, benchmarking history, release trust and the full desktop experience.

The available 3.8.0 report covers three subsystems—System Doctor, Network Intelligence and Guardian—not the entire product tree. Optimizer and Customization Studio reports are from earlier 3.6.x source passes. They are useful evidence for feature placement, but do not prove that every change is present in one integrated 3.8.0 source package.

## 2. Status legend

| Status | Meaning |
|---|---|
| **Implemented (source-reported)** | The implementation report describes the feature as delivered. Native Windows runtime validation may still be pending. |
| **Partial** | A limited workflow exists, with specific functions not implemented. |
| **Catalogue only** | Entries exist for research/reference; they are not directly executable. |
| **Proposal only** | A concept or recommendation exists without an operational feature. |
| **Planned / missing** | Needed for the target architecture but not evidenced as implemented. |
| **Excluded** | Intentionally outside the supported product boundary. |
| **Lineage unresolved** | Report exists, but integration into the full 3.8.0 source tree is unavailable for verification. |

## 3. Feature-to-architecture map

| Feature / area | Report-backed status | Core ownership | Primary suite | Evidence and limits |
|---|---|---|---|---|
| **System Doctor** | Implemented (source-reported); lineage unresolved | Intelligence, Guardian, Device | Control Center | Read-only OS/storage/memory/security/reboot/event/WinRE triage. Findings include severity, source, evidence, confidence and manual recommendations. No automatic repair. |
| **Network Intelligence** | Implemented (source-reported); lineage unresolved | Network, Intelligence, Device | Device & Network Center | User-initiated low-volume ICMP, resolver-call and TCP 443 checks; adapter/default-route context; packet-loss, RTT, median and inter-reply-delta reporting. DNS timing is resolver-call duration, not raw DNS RTT. |
| **SAGE Guardian audit** | Implemented (source-reported); lineage unresolved | Guardian, SAGE Core | Guardian Center | Read-only snapshot catalog, transaction journal, WinRE and selected backup-posture audit. Explicit-path legacy journal inspection; audit does not create folders, copy or migrate state. |
| **Snapshot creation and restore** | Partial / narrowly scoped | Guardian, SAGE Core | Guardian Center | Snapshot creation is a separate user-confirmed action. Restore is limited to validated current-user SAGE State, Profiles and Config; it is not a general Windows image restore. |
| **Optimizer Suite** | Implemented (source-reported in 3.6.4); 3.8 integration unresolved | SAGE Core, Device, Gaming, Intelligence | Control Center | Evidence-first system overview, startup/process inventory, application-health sampling, update discovery, launcher scanning, telemetry and limited recoverable TEMP quarantine. Process inventory does not stop or reprioritize processes. Quarantine is narrow, previewed, approval-gated, journaled and hash-checked. |
| **Optimizer catalogues** | Catalogue only | SAGE Core, Intelligence | Control Center | Modern 26, Research 132, SAGE-600 600 and SAGE-7000 7,000 (7,758 records total in the cited report). Catalogue is not directly executed. Tier labels are evidence maturity, not approval. |
| **Startup/process inventory** | Implemented (source-reported) | SAGE Core, Device | Control Center | Startup arguments are omitted; impact is labelled NotMeasured. Process inventory shows working set, private memory and CPU time. It does not terminate, suspend or reprioritize processes. |
| **Game/launcher discovery and app health** | Implemented (source-reported in earlier source pass) | Gaming, Device, Intelligence | Gaming Center | Inventory and process matching, launcher-library scanning and health sampling are described. A complete per-game profile preview/apply/revert workflow is not established. |
| **Gaming telemetry / PresentMon / benchmarks** | Partial | Gaming, Device, Evidence Foundation | Gaming Center | Project reports describe telemetry and PresentMon CSV analysis/comparison. Persistent benchmark history, aggregation and reliable live capture remain gaps requiring source verification and runtime tests. |
| **Customization Studio** | Partial / source-reported in 3.6.8 | SAGE Core, Device, Guardian | SAGE Studio | Four themes; data-only .sagetheme import/export; current-user light/dark and transparency preferences plus wallpaper; preview, approval, snapshot, journal, verification and conflict-aware rollback. Accent application is preview-only. |
| **Taskbar / Start / Explorer / shell styling** | Partial / planned | SAGE Core, Device, Guardian | SAGE Studio | The 3.6.8 report says taskbar, Start, Explorer, lock screen, per-monitor layouts, cursor/icon replacement, sound schemes and widgets were not implemented by that milestone; supported Settings handoffs exist. |
| **Desktop Experience shell** | Partial / planned | SAGE Core, Device, Guardian | Desktop Experience | Earlier reports reference some launcher/flyout controls. A complete launcher, command palette, workspaces, tiling/window management, widget framework, status surfaces, multi-monitor behavior and accessibility pass are not evidenced as complete. |
| **Intelligence / AI Assistant** | Partial / proposal-only by capability | Intelligence | Cross-suite surface | Deterministic Doctor findings remain authoritative. An earlier report describes local AI summarization without repair/tool-execution rights. A unified provider, trusted structured output and complete consent/data-preview flow remain gaps. |
| **Update Center / Store** | Partial | SAGE Core, Trust Foundation | Control Center | Reports describe consent-gated WinGet update discovery (query only/no install) and SDK offers. A signed, staged, rollback-capable SAGE updater and verified release channel are not evidenced as complete. |
| **Compatibility Foundation** | Partial / requires reconciliation | Shared foundation | All suites | A separate compatibility/dependency/security preflight exists on an isolated GitHub branch, not merged. Repository main is older 3.6.x lineage; full 3.8.0 source is unavailable here. |
| **Trust / release pipeline** | Partial | Trust Foundation | Control Center (release/update surface) | Reports include manifests, static validators and SHA-256 source archive sidecars. Native builds, signed release verification and production APBX certification are not established by those checks. |
| **Support bundle** | Planned / missing | Intelligence, Guardian, Evidence Foundation | Guardian Center | Needs redacted export containing build identity, capability report, operation IDs, relevant logs and evidence, with privacy preview and explicit export. |
| **Unified operation broker** | Planned / missing (P0) | SAGE Core + all foundations | Shared service; surfaced by suites | Gap audit identifies missing central typed command broker, policy enforcement at the apply engine, cancellation/timeouts/progress/error codes, audit IDs, integrity controls and elevation model. |
| **Canonical capability registry** | Planned / missing (P0) | Compatibility, Policy, Evidence, Trust | All suites | UI must derive availability from one source of truth with implemented/partial/catalog-only/blocked/planned/excluded state, supported lanes and validation evidence. |
| **Voidstrap / Roblox settings integration** | Legacy research; not counted as 3.8.0 delivery | Gaming, Intelligence, Guardian | Gaming Center | Earlier report documents read-only compatibility research and a stale FastFlag snapshot with client writes disabled. Keep it isolated from general Windows optimization and anti-cheat-sensitive behavior. |

## 4. Foundation readiness snapshot

| Foundation | Existing evidence | Main gap | Readiness |
|---|---|---|---|
| Compatibility | OS identity and compatibility checks; isolated dependency/security preflight PR | One canonical capability registry, repo/source lineage reconciliation, per-lane tests | Partial |
| Execution | Guarded apply modules and narrow PowerShell workflows described in older reports | One typed broker with central policy, cancellation, timeout, progress, output/error contract and controlled elevation | Blocker |
| Policy | Preview/explicit approval in some workflows; user-initiated network probes | Policy gate enforced inside the executor for every mutating operation | Partial |
| State | Journals, snapshots, verify and scoped rollback in Customization/Optimizer/Guardian reports | Unified transaction model, power-failure recovery and wider disposable-VM restore proof | Partial |
| Evidence | Doctor evidence/confidence, network measurements, telemetry, static validators | Persistent benchmark history; canonical per-entry evidence and redacted support bundle | Partial |
| Trust | Hash sidecars, manifests, dependency/security inventory, source validation | Signed manifests/artifacts, SBOM/licensing, trusted updater and production release certification | Blocker |

## 5. Suite readiness snapshot

| Suite | Evidence-backed parts | Missing before the suite is complete |
|---|---|---|
| Control Center | Optimizer page; diagnostics; compatibility/dependency reporting; Store/update discovery surfaces | Complete capability-led home, unified operation history, trusted updater and one cross-feature broker |
| Gaming Center | Game/launcher inventory; application health; telemetry/benchmark capabilities described in project reports | Complete per-game profile workflow, live evidence integration, persistent benchmarks and game compatibility matrix |
| SAGE Studio | Theme packs; import/export; controlled appearance transactions; native Settings handoffs | Complete editor, accent apply, taskbar/Start/Explorer/lock-screen and per-monitor support |
| Desktop Experience | Some existing launcher/flyout start/stop references | Complete runtime interaction layer, workspace/window management, widgets, status UI, accessibility and robust shell recovery |
| Device & Network Center | Device inventory, limited adapter/device information, Network Intelligence probes | Provider-based sensors/driver/device inventory, history, Wi-Fi detail and diagnostics integration |
| Guardian Center | Guardian audit, journal/snapshot catalog, WinRE/backup posture and selected restore path | Broader recovery orchestration, support bundle, interrupted-restore/tamper recovery tests and clearer recovery UX |

## 6. Consolidation decisions

1. **One canonical optimization catalogue.** Merge SAGE-600, SAGE-6200/SAGE-7000 and research records into one schema. Preserve original IDs as aliases. Mark every item executable, proposal-only, research-only, deprecated or rejected. Never infer approval from a tier label.
2. **One feature registry.** The UI, compatibility gate and support reports read the same capability record; remove hard-coded feature availability.
3. **One operation broker.** Replace direct page-to-script calls and inconsistent Apply/Revert routes with typed operations through policy, state, execution and evidence.
4. **One transaction/journal contract.** Optimizer, theme apply, profile apply and recovery use the same transaction lifecycle, even when compensation adapters differ.
5. **One intelligence provider interface.** Deterministic rules are authoritative; AI may explain or summarize within explicit data/network consent and without implicit execution rights.
6. **One benchmark record format.** Store device/driver/OS/game/profile/build identity, capture method, sample window, FPS/frame-time distribution and provenance. No synthetic composite score or universal FPS promise.
7. **Separate Studio and Desktop Experience.** Studio authors personalization; Desktop Experience hosts live interaction surfaces. A theme can be consumed by shell surfaces without shifting ownership.
8. **Keep deployment lanes independent.** Standalone client, legacy companion and AME/APBX playbook require separate supported capabilities and release gates.

## 7. Immediate P0 blockers

- Obtain and verify the full 3.8.0 source ZIP (including its exact SHA-256 sidecar) and establish its Git commit/branch ancestry.
- Reconcile the 3.8.0 source with the connected GitHub repository's older main branch. Do not merge the compatibility PR or architecture RFC directly into main before lineage is resolved.
- Define the feature/capability registry and typed operation contract before adding more scripts or UI pages.
- Move policy checks into the operation broker; UI visibility is not a security boundary.
- Normalize duplicate optimization catalogues and record implementation/evidence maturity per item.
- Define native Windows CI and runtime gates for each supported deployment lane.

## 8. Source reports used

- SAGE OS 3.8.0 — System Doctor, Network Intelligence and Guardian (source-only report).
- SAGE OS 3.6.8 — Customization Studio implementation report.
- SAGE OS 3.6.4 — Optimizer Suite implementation report.
- SAGE OS 3.6.3 — comprehensive gap audit and capability matrix.
- SAGE OS 3.6.3 — platform support/release architecture report.
- Earlier Intelligent Doctor/Voidstrap research report (legacy research only).
