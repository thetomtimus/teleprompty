#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: verify-m0-proof-provenance.sh [--repository PATH] MANIFEST [EVIDENCE]

Fail-closed local provenance validation for a Private Presenter M0 proof build.
When EVIDENCE is supplied, the configuration, cohort, completion, and permanent
validity state are checked against the manifest and PRIVATE_PRESENTER_* cell
variables. This is local provenance, not signing or security attestation.
USAGE
  exit 64
}

repository=''
if [[ "${1:-}" == '--repository' ]]; then
  [[ $# -ge 3 ]] || usage
  repository=$2
  shift 2
fi
[[ $# -eq 1 || $# -eq 2 ]] || usage
manifest=$1
evidence=${2:-}

if [[ -z "$repository" ]]; then
  repository=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo 'error: provenance repository could not be resolved.' >&2
    exit 1
  }
fi

python3 - "$repository" "$manifest" "$evidence" <<'PY'
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Iterable


FIXED_FAILURE_CODES = {
    "EVIDENCE_OPEN_FAILED",
    "EVIDENCE_APPEND_FAILED",
    "EVIDENCE_FLUSH_FAILED",
    "EVIDENCE_PATH_UNRESOLVED",
    "EVIDENCE_QUEUE_OVERFLOW",
    "EVIDENCE_CLOSE_FAILED",
    "EVIDENCE_FINALIZE_FAILED",
    "CONFIG_COMMIT_INVALID",
    "CONFIG_LEVEL_INVALID",
    "CONFIG_ORDERING_INVALID",
    "CONFIG_CONTROLLER_COHORT_INVALID",
    "CONFIG_REPETITION_INVALID",
    "CONTROLLER_COHORT_MISMATCH",
    "HOT_KEY_REGISTRATION_FAILED",
    "CONFIG_EXECUTABLE_HASH_INVALID",
    "CONFIG_BUILD_LOG_PATH_INVALID",
    "CONFIG_BUILD_LOG_HASH_INVALID",
    "CONFIG_BUILD_MANIFEST_PATH_INVALID",
    "PROVENANCE_EXECUTABLE_HASH_MISMATCH",
    "PROVENANCE_BUILD_LOG_HASH_MISMATCH",
    "PROVENANCE_HEAD_MISMATCH",
}
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")
MANIFEST_KEYS = {
    "commit",
    "clean_head",
    "executable_path",
    "executable_sha256",
    "build_log_path",
    "build_log_sha256",
}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run_git(repository: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repository), *args],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        fail("Git provenance check failed.")
    return result.stdout.rstrip("\n")


def resolved_existing_file(raw_path: str, label: str, executable: bool = False) -> Path:
    path = Path(raw_path)
    if not path.is_absolute() or path != path.resolve(strict=False):
        fail(f"{label} must be an absolute resolved local path.")
    if not path.is_file():
        fail(f"{label} is missing.")
    if executable and not os.access(path, os.X_OK):
        fail("proof executable is not executable.")
    return path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_manifest(path: Path) -> dict[str, str]:
    if not path.is_absolute() or path != path.resolve(strict=False):
        fail("proof manifest must be an absolute resolved local path.")
    if not path.is_file():
        fail("proof manifest is missing.")
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or "=" not in line:
            fail("proof manifest contains a malformed line.")
        key, value = line.split("=", 1)
        if key in values:
            fail("proof manifest contains a duplicate key.")
        values[key] = value
    if set(values) != MANIFEST_KEYS:
        fail("proof manifest key set is not exact.")
    return values


def recursive_values(item: Any, keys: set[str]) -> Iterable[Any]:
    if isinstance(item, dict):
        for key, value in item.items():
            if key in keys:
                yield value
            yield from recursive_values(value, keys)
    elif isinstance(item, list):
        for value in item:
            yield from recursive_values(value, keys)


def first_value(record: dict[str, Any], *keys: str) -> Any | None:
    values = list(recursive_values(record, set(keys)))
    return values[0] if values else None


def recursive_strings(item: Any) -> Iterable[str]:
    if isinstance(item, str):
        yield item
    elif isinstance(item, dict):
        for key, value in item.items():
            yield key
            yield from recursive_strings(value)
    elif isinstance(item, list):
        for value in item:
            yield from recursive_strings(value)


repository = Path(sys.argv[1]).resolve(strict=True)
manifest_path = Path(sys.argv[2])
evidence_argument = sys.argv[3]
manifest = parse_manifest(manifest_path)

head = run_git(repository, "rev-parse", "HEAD")
if not HEX40.fullmatch(head):
    fail("repository HEAD is not a full lowercase commit.")
if run_git(repository, "status", "--porcelain", "--untracked-files=all"):
    fail("repository working tree is dirty.")
if manifest["clean_head"] != "true":
    fail("proof manifest does not bind a clean HEAD.")
if not HEX40.fullmatch(manifest["commit"]) or manifest["commit"] != head:
    fail("proof manifest commit does not match clean HEAD.")
if not HEX64.fullmatch(manifest["executable_sha256"]):
    fail("proof executable SHA-256 is malformed.")
if not HEX64.fullmatch(manifest["build_log_sha256"]):
    fail("proof build-log SHA-256 is malformed.")

executable = resolved_existing_file(
    manifest["executable_path"], "proof executable", executable=True
)
build_log = resolved_existing_file(manifest["build_log_path"], "proof build log")
if sha256(executable) != manifest["executable_sha256"]:
    fail("proof executable SHA-256 mismatch.")
if sha256(build_log) != manifest["build_log_sha256"]:
    fail("proof build-log SHA-256 mismatch.")
try:
    build_log_lines = build_log.read_text(encoding="utf-8").splitlines()
except UnicodeDecodeError:
    fail("proof build log is not UTF-8 text.")
build_commits = [line.removeprefix("commit=") for line in build_log_lines if line.startswith("commit=")]
build_statuses = [
    line.removeprefix("status_porcelain=")
    for line in build_log_lines
    if line.startswith("status_porcelain=")
]
if build_commits != [manifest["commit"]]:
    fail("proof build log does not bind exactly one matching commit.")
if build_statuses != [""]:
    fail("proof build log does not bind exactly one clean status_porcelain header.")

if not evidence_argument:
    print(f"M0 proof provenance valid for clean commit {head}.")
    raise SystemExit(0)

evidence = resolved_existing_file(evidence_argument, "final evidence")
if evidence.name.endswith(".pending") or Path(str(evidence) + ".pending").exists():
    fail("pending evidence is never accepted as proof.")
try:
    lines = [
        json.loads(line)
        for line in evidence.read_text(encoding="utf-8").splitlines()
        if line
    ]
except (UnicodeDecodeError, json.JSONDecodeError):
    fail("evidence is not valid UTF-8 JSON Lines.")
if not lines or not all(isinstance(line, dict) for line in lines):
    fail("evidence contains no complete typed records.")
if first_value(lines[0], "kind") != "configurationBound":
    fail("configurationBound is not the first evidence record.")
if sum(first_value(line, "kind") == "configurationBound" for line in lines) != 1:
    fail("evidence must contain exactly one configurationBound.")
if first_value(lines[-1], "kind") != "sessionCompletion":
    fail("sessionCompletion is not the terminal evidence record.")
if sum(first_value(line, "kind") == "sessionCompletion" for line in lines) != 1:
    fail("evidence must contain exactly one sessionCompletion.")
if sum(first_value(line, "kind") == "sessionEnded" for line in lines) != 1:
    fail("evidence must contain exactly one sessionEnded.")

session_ids = [first_value(line, "sessionID") for line in lines]
if any(not isinstance(value, str) or not value for value in session_ids):
    fail("every evidence record must bind a sessionID.")
if len(set(session_ids)) != 1:
    fail("evidence records span more than one session.")
sequences = [first_value(line, "sequence") for line in lines]
if any(not isinstance(value, int) or isinstance(value, bool) or value <= 0 for value in sequences):
    fail("every evidence record must have a positive integer sequence.")
if sequences != sorted(sequences) or len(set(sequences)) != len(sequences):
    fail("evidence sequence is not globally strict and unique.")

configuration = lines[0]
expected = {
    "commit": manifest["commit"],
    "executableSHA256": manifest["executable_sha256"],
    "buildLogPath": manifest["build_log_path"],
    "buildLogSHA256": manifest["build_log_sha256"],
    "buildManifestPath": str(manifest_path),
    "level": os.environ.get("PRIVATE_PRESENTER_PROOF_LEVEL"),
    "ordering": os.environ.get("PRIVATE_PRESENTER_ORDERING"),
    "declaredControllerCohort": os.environ.get(
        "PRIVATE_PRESENTER_CONTROLLER_COHORT"
    ),
    "repetition": os.environ.get("PRIVATE_PRESENTER_REPETITION"),
}
if any(value is None for value in expected.values()):
    fail("expected cell configuration environment is incomplete.")
aliases = {
    "commit": ("commit", "implementationCommit"),
    "level": ("level", "proofLevel"),
    "ordering": ("ordering", "orderingMode"),
    "declaredControllerCohort": (
        "declaredControllerCohort",
        "controllerCohort",
    ),
    "repetition": ("repetition",),
    "executableSHA256": ("executableSHA256", "proofExecutableSHA256"),
    "buildLogPath": ("buildLogPath", "proofBuildLogPath"),
    "buildLogSHA256": ("buildLogSHA256", "proofBuildLogSHA256"),
    "buildManifestPath": ("buildManifestPath", "proofManifestPath"),
}
for field, expected_value in expected.items():
    if first_value(configuration, *aliases[field]) != expected_value:
        fail(f"evidence configuration mismatch for {field}.")

declared = first_value(configuration, *aliases["declaredControllerCohort"])
observed_records = [
    line
    for line in lines
    if first_value(line, "kind") == "controllerCohortObserved"
]
if len(observed_records) != 1:
    fail("evidence must contain exactly one controllerCohortObserved record.")
observed = first_value(
    observed_records[0],
    "observedControllerCohort",
    "controllerCohort",
    "cohort",
)
if observed != declared:
    fail("declared and observed controller cohorts do not match.")

# Phase A has exactly three H correlations. Phase B adds exactly two L
# correlations. Unrelated lifecycle/operation records may interleave, but none
# may replace, duplicate, or reorder a required event inside a correlation.
required_kinds = [
    "carbonReceived",
    "mainDispatchBegan",
    "commandBefore",
    "commandAfter",
    "focusImmediate",
    "focusNextMainRunLoop",
    "focusDelayed100Milliseconds",
    "focusDelayed500Milliseconds",
    "correlationWindowClosed",
]
carbon_records = [line for line in lines if first_value(line, "kind") == "carbonReceived"]
carbon_correlations = [first_value(line, "correlationID") for line in carbon_records]
if len(carbon_correlations) not in (3, 5) or any(
    not isinstance(value, str) or not value for value in carbon_correlations
):
    fail("evidence must contain three Phase A H receipts or three H plus two L receipts.")
if len(set(carbon_correlations)) != len(carbon_correlations):
    fail("each H/L receipt must have a unique correlationID.")

visibility_commands: list[str] = []
lock_commands: list[str] = []
for correlation_id in carbon_correlations:
    correlated = [
        line for line in lines if first_value(line, "correlationID") == correlation_id
    ]
    positions: list[int] = []
    for kind in required_kinds:
        matches = [line for line in correlated if first_value(line, "kind") == kind]
        if len(matches) != 1:
            fail(f"H/L correlation is incomplete or duplicates required event {kind}.")
        positions.append(first_value(matches[0], "sequence"))
    if positions != sorted(positions) or len(set(positions)) != len(positions):
        fail("H/L correlation required events are out of sequence.")
    carbon_record = next(
        line for line in correlated if first_value(line, "kind") == "carbonReceived"
    )
    hot_key_action = first_value(carbon_record, "hotKeyAction")
    command_values: list[str] = []
    for kind in ("commandBefore", "commandAfter"):
        command_record = next(
            line for line in correlated if first_value(line, "kind") == kind
        )
        command = first_value(command_record, "command")
        if not isinstance(command, str):
            fail("H/L correlation command is missing.")
        command_values.append(command)
    if len(set(command_values)) != 1:
        fail("H/L commandBefore and commandAfter do not match.")
    if hot_key_action == "visibility":
        visibility_commands.append(command_values[0])
    elif hot_key_action == "lock":
        lock_commands.append(command_values[0])
    else:
        fail("H/L receipt is missing its typed action.")

if visibility_commands != ["showOverlay", "hideOverlay", "showOverlay"]:
    fail("H correlations do not match cold show/hide/show sequence.")
if len(carbon_correlations) == 3 and lock_commands:
    fail("Phase A evidence unexpectedly contains L correlations.")
if len(carbon_correlations) == 5 and lock_commands != ["toggleLock", "toggleLock"]:
    fail("Phase B evidence must contain exactly two toggleLock correlations.")

required_records = [line for line in lines if first_value(line, "kind") in required_kinds]
if any(first_value(line, "correlationID") not in set(carbon_correlations) for line in required_records):
    fail("required H/L event is uncorrelated or belongs to an undeclared correlation.")

if len(carbon_correlations) == 5:
    frame_records = [
        line
        for line in lines
        if first_value(line, "kind") == "panelOperation"
        and first_value(line, "panelOperation") == "applyContainedFrame"
        and first_value(line, "appliedFrame") is not None
    ]
    if len(frame_records) < 9:
        fail("Phase B evidence does not export enough applied frames for header and eight zones.")

all_strings = set(recursive_strings(lines))
if all_strings.intersection(FIXED_FAILURE_CODES):
    fail("evidence contains a permanent recorder/configuration fault.")
if any(value == "recorderFault" for value in all_strings):
    fail("evidence contains a recorder fault.")
if any(value == "invalid" or value.startswith("invalid(") for value in all_strings):
    fail("evidence proof status is permanently invalid.")

completion_strings = set(recursive_strings(lines[-1]))
if "valid" not in completion_strings:
    fail("terminal sessionCompletion does not bind valid proof status.")
completion_commit = first_value(lines[-1], "commit", "implementationCommit")
if completion_commit not in (None, manifest["commit"]):
    fail("terminal completion commit mismatch.")

print(f"M0 evidence and provenance valid for clean commit {head}.")
PY
