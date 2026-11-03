#!/usr/bin/env python3
"""Validate SAGE 6x6x6 contract schemas and architecture cross-references.

Requires jsonschema; validates Draft 2020-12 meta-schema correctness and the
architecture registry references. Runtime contract enforcement is separate.
"""
from __future__ import annotations

import json
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_DIR = ROOT / "Catalog" / "Architecture" / "Schemas"
REGISTRY = ROOT / "Catalog" / "Architecture" / "SAGE-Architecture-6x6x6.json"

SCHEMA_FILES = {
    "capability-descriptor.schema.json": {"schemaVersion", "id", "name", "ownerCore", "primarySuite", "status", "integrationStatus", "deploymentLanes", "validation"},
    "operation-request.schema.json": {"contractVersion", "operationId", "featureId", "caller", "action", "mode", "target", "riskTier", "requestedAt"},
    "operation-preview.schema.json": {"schemaVersion", "reference", "operationId", "featureId", "target", "compatibilitySnapshotId", "previewHash", "expiresAt", "plannedChanges"},
    "policy-decision.schema.json": {"schemaVersion", "decisionId", "operationId", "decision", "riskTier", "policyVersion", "evaluatedAt", "reasons", "approval"},
    "transaction-journal.schema.json": {"schemaVersion", "transactionId", "operationId", "featureId", "state", "createdAt", "updatedAt", "steps", "recovery"},
    "evidence-record.schema.json": {"schemaVersion", "evidenceId", "recordType", "claimType", "observedAt", "source", "provenance", "privacyClass", "payload"},
    "release-trust-manifest.schema.json": {"manifestVersion", "product", "version", "channel", "createdAt", "source", "artifacts", "signer", "signature"},
}

def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)

def main() -> int:
    failures: list[str] = []
    loaded = {}
    for filename, expected_required in SCHEMA_FILES.items():
        path = SCHEMA_DIR / filename
        if not path.is_file():
            failures.append(f"missing schema: {filename}")
            continue
        try:
            schema = load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            failures.append(f"invalid JSON in {filename}: {exc}")
            continue
        loaded[filename] = schema
        if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
            failures.append(f"wrong JSON Schema dialect: {filename}")
        if not schema.get("$id", "").startswith("urn:sageos:schema:architecture:"):
            failures.append(f"missing stable schema ID: {filename}")
        required = set(schema.get("required", []))
        if not expected_required.issubset(required):
            failures.append(f"missing required contract fields in {filename}: {sorted(expected_required - required)}")
        if schema.get("type") != "object":
            failures.append(f"top-level schema must be object: {filename}")
        try:
            Draft202012Validator.check_schema(schema)
        except Exception as exc:
            failures.append(f"invalid JSON Schema in {filename}: {exc}")

    try:
        registry = load_json(REGISTRY)
    except (OSError, json.JSONDecodeError) as exc:
        failures.append(f"invalid architecture registry: {exc}")
        registry = {}

    foundations = registry.get("foundations", [])
    cores = registry.get("cores", [])
    suites = registry.get("suites", [])
    features = registry.get("features", [])

    if len(foundations) != 6 or {x.get("id") for x in foundations} != {f"F{i}" for i in range(1, 7)}:
        failures.append("architecture registry must define exactly F1-F6")
    if len(cores) != 6 or {x.get("id") for x in cores} != {f"C{i}" for i in range(1, 7)}:
        failures.append("architecture registry must define exactly C1-C6")
    if len(suites) != 6 or {x.get("id") for x in suites} != {f"S{i}" for i in range(1, 7)}:
        failures.append("architecture registry must define exactly S1-S6")
    for core in cores:
        if set(core.get("foundationDependencies", [])) != {f"F{i}" for i in range(1, 7)}:
            failures.append(f"{core.get('id')} must depend on every foundation")
    feature_ids = [feature.get("id") for feature in features]
    if len(feature_ids) != len(set(feature_ids)):
        failures.append("duplicate feature IDs in architecture registry")

    valid_core_ids = {f"C{i}" for i in range(1, 7)}
    valid_suite_ids = {f"S{i}" for i in range(1, 7)}
    for feature in features:
        if feature.get("ownerCore") and feature["ownerCore"] not in valid_core_ids:
            failures.append(f"invalid ownerCore for {feature.get('id')}")
        if not set(feature.get("cores", [])).issubset(valid_core_ids):
            failures.append(f"invalid core reference for {feature.get('id')}")
        if not set(feature.get("suites", [])).issubset(valid_suite_ids):
            failures.append(f"invalid suite reference for {feature.get('id')}")

    # Exercise representative valid and invalid contract instances. These
    # cases validate schema behavior, not runtime enforcement of the contracts.
    instance_cases = 0

    def check_instance(schema_name: str, label: str, instance: dict, expected_valid: bool) -> None:
        nonlocal instance_cases
        schema = loaded.get(schema_name)
        if schema is None:
            return
        actual_valid = Draft202012Validator(schema).is_valid(instance)
        instance_cases += 1
        if actual_valid != expected_valid:
            expectation = "valid" if expected_valid else "invalid"
            failures.append(f"{label}: expected {expectation} instance")

    capability = {
        "schemaVersion": "1.0.0",
        "id": "diagnostics.system-doctor",
        "name": "System Doctor",
        "ownerCore": "C3",
        "primarySuite": "S1",
        "status": "implemented_source_reported",
        "integrationStatus": "lineage_unresolved",
        "deploymentLanes": ["standalone-modern"],
        "validation": {
            "static": "passed",
            "windowsPowerShell51": "pending",
            "windowsPowerShell7": "pending",
            "nativeBuild": "pending",
            "windows10Runtime": "pending",
            "windows11Runtime": "pending",
            "recovery": "pending",
            "apbx": "pending",
            "evidenceRefs": ["Docs/SAGE-3.8.0-CAPABILITY-MAP.md"]
        }
    }
    check_instance("capability-descriptor.schema.json", "capability descriptor example", capability, True)

    operation = {
        "contractVersion": "1.0.0",
        "operationId": "11111111-1111-4111-8111-111111111111",
        "featureId": "diagnostics.system-doctor",
        "caller": {"coreId": "C3", "suiteId": "S1"},
        "action": "inspect",
        "mode": "read_only",
        "target": {"scope": "user", "resource": "system"},
        "riskTier": "none",
        "requestedAt": "2026-11-03T19:00:00Z"
    }
    check_instance("operation-request.schema.json", "read-only inspect operation", operation, True)
    invalid_read_only_apply = dict(operation, action="apply")
    check_instance("operation-request.schema.json", "read-only apply rejection", invalid_read_only_apply, False)
    mutating_apply = dict(operation, action="apply", mode="mutating", riskTier="medium")
    check_instance("operation-request.schema.json", "mutating apply operation", mutating_apply, True)

    preview_instance = {
        "schemaVersion": "1.0.0",
        "reference": "preview-1",
        "operationId": operation["operationId"],
        "featureId": "optimizer.temp-quarantine",
        "target": {"scope": "user", "resource": "temp-files"},
        "compatibilitySnapshotId": "compatibility-snapshot-1",
        "previewHash": "c" * 64,
        "expiresAt": "2026-11-03T20:00:00Z",
        "plannedChanges": ["Quarantine selected eligible temporary files"]
    }
    check_instance("operation-preview.schema.json", "operation preview instance", preview_instance, True)

    policy = {
        "schemaVersion": "1.0.0",
        "decisionId": "22222222-2222-4222-8222-222222222222",
        "operationId": operation["operationId"],
        "decision": "require_approval",
        "riskTier": "medium",
        "policyVersion": "1.0.0",
        "evaluatedAt": "2026-11-03T19:00:00Z",
        "reasons": [{"code": "USER_APPROVAL_REQUIRED", "message": "Approval is required before mutation."}],
        "approval": {"required": True, "granted": False}
    }
    check_instance("policy-decision.schema.json", "approval-required policy decision", policy, True)
    invalid_policy = dict(policy, approval={"required": False, "granted": False})
    check_instance("policy-decision.schema.json", "approval-required policy rejection", invalid_policy, False)
    approved_policy = dict(policy, decision="allow", approval={
        "required": True,
        "granted": True,
        "actorId": "test-user",
        "grantedAt": "2026-11-03T19:00:00Z",
        "approvedScopes": ["user"],
        "expiresAt": "2026-11-03T19:05:00Z",
        "operationId": operation["operationId"],
        "featureId": "optimizer.temp-quarantine",
        "target": {"scope": "user", "resource": "temp-files"},
        "previewHash": "c" * 64
    })
    check_instance("policy-decision.schema.json", "preview-bound approval", approved_policy, True)
    invalid_approved_policy = dict(approved_policy, approval={
        "required": True,
        "granted": True,
        "actorId": "test-user",
        "grantedAt": "2026-11-03T19:00:00Z",
        "approvedScopes": ["user"],
        "expiresAt": "2026-11-03T19:05:00Z",
        "operationId": operation["operationId"],
        "featureId": "optimizer.temp-quarantine",
        "target": {"scope": "user", "resource": "temp-files"}
    })
    check_instance("policy-decision.schema.json", "approval without preview hash rejection", invalid_approved_policy, False)

    transaction = {
        "schemaVersion": "1.0.0",
        "transactionId": "33333333-3333-4333-8333-333333333333",
        "operationId": operation["operationId"],
        "featureId": "optimizer.temp-quarantine",
        "state": "prepared",
        "createdAt": "2026-11-03T19:00:00Z",
        "updatedAt": "2026-11-03T19:00:00Z",
        "steps": [],
        "recovery": {"required": False, "state": "not_required", "attemptCount": 0}
    }
    check_instance("transaction-journal.schema.json", "prepared transaction journal", transaction, True)

    evidence = {
        "schemaVersion": "1.0.0",
        "evidenceId": "44444444-4444-4444-8444-444444444444",
        "featureId": "diagnostics.system-doctor",
        "recordType": "measurement",
        "claimType": "observed",
        "observedAt": "2026-11-03T19:00:00Z",
        "source": {"kind": "windows_api", "name": "GlobalMemoryStatusEx"},
        "provenance": {"captureMethod": "Windows API query", "sourceVersion": "1"},
        "confidence": 1.0,
        "privacyClass": "none",
        "payload": {"availablePhysicalBytes": 1048576}
    }
    check_instance("evidence-record.schema.json", "observed evidence record", evidence, True)

    release = {
        "manifestVersion": "1.0.0",
        "product": "SAGE OS",
        "version": "3.8.0-preview.1",
        "channel": "preview",
        "createdAt": "2026-11-03T19:00:00Z",
        "source": {"repository": "wukong0060/SAGE-OS-", "commit": "a" * 40},
        "artifacts": [{
            "name": "SAGE-Control-Center-x64",
            "path": "artifacts/SAGE-Control-Center-x64.zip",
            "sha256": "a" * 64,
            "sizeBytes": 1024,
            "architecture": "x64",
            "kind": "control_center"
        }],
        "signer": {
            "identity": "SAGE Release",
            "algorithm": "Ed25519",
            "certificateFingerprint": "b" * 40
        },
        "signature": {"algorithm": "Ed25519", "encoding": "base64", "value": "c2ln"}
    }
    check_instance("release-trust-manifest.schema.json", "release trust manifest", release, True)
    invalid_release = dict(release, version="3x8x0")
    check_instance("release-trust-manifest.schema.json", "invalid release version rejection", invalid_release, False)

    if failures:
        print("SAGE architecture contract validation FAILED")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print(f"PASS: {len(loaded)}/{len(SCHEMA_FILES)} Draft 2020-12 schemas validated")
    print("PASS: architecture registry contains 6 foundations, 6 cores and 6 suites")
    print(f"PASS: {len(feature_ids)} unique feature IDs and valid core/suite references")
    print(f"PASS: {instance_cases} positive/negative contract instance checks")
    print("NOTE: schema validity and registry consistency only; runtime contract enforcement and Windows tests remain separate")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
