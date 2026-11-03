#!/usr/bin/env python3
"""Static consistency checks for the proposed SAGE 6x6x6 contract schemas.

This validator uses only the Python standard library. It checks schema structure
and architecture cross-references; it is not a JSON Schema instance validator.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_DIR = ROOT / "Catalog" / "Architecture" / "Schemas"
REGISTRY = ROOT / "Catalog" / "Architecture" / "SAGE-Architecture-6x6x6.json"

SCHEMA_FILES = {
    "capability-descriptor.schema.json": {"schemaVersion", "id", "name", "ownerCore", "primarySuite", "status", "integrationStatus", "deploymentLanes", "validation"},
    "operation-request.schema.json": {"contractVersion", "operationId", "featureId", "caller", "action", "mode", "target", "riskTier", "requestedAt"},
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

    if failures:
        print("SAGE architecture contract validation FAILED")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print(f"PASS: {len(loaded)}/{len(SCHEMA_FILES)} contract schemas parsed and checked")
    print("PASS: architecture registry contains 6 foundations, 6 cores and 6 suites")
    print(f"PASS: {len(feature_ids)} unique feature IDs and valid core/suite references")
    print("NOTE: static consistency only; full JSON Schema instance and Windows runtime tests remain separate")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
