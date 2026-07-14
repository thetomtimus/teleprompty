#!/usr/bin/env bash
set -euo pipefail

script_root=$(cd "$(dirname "$0")" && pwd)
verifier="$script_root/verify-m0-proof-provenance.sh"
runner="$script_root/run-m0-phase-a-diagnosis.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/private-presenter-provenance.XXXXXX")
fixture_root=$(cd "$fixture_root" && pwd -P)
trap 'rm -rf "$fixture_root"' EXIT

repository="$fixture_root/repository"
artifacts="$fixture_root/artifacts"
mkdir -p "$repository" "$artifacts"
git -C "$repository" init -q
git -C "$repository" config user.name 'Generated Fixture'
git -C "$repository" config user.email 'generated-fixture@example.invalid'
printf 'fixture\n' > "$repository/tracked.txt"
git -C "$repository" add tracked.txt
git -C "$repository" commit -qm 'generated fixture'

executable="$artifacts/Private Presenter"
build_log="$artifacts/proof-build.log"
manifest="$artifacts/proof-build-manifest.txt"
evidence="$artifacts/evidence.txt"
printf '#!/usr/bin/env bash\nexit 0\n' > "$executable"
chmod +x "$executable"

hash_file() {
  python3 - "$1" <<'PY'
from pathlib import Path
import hashlib
import sys
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}
different_hex() {
  local value=$1
  if [[ ${value:0:1} == 0 ]]; then
    printf '1%s\n' "${value:1}"
  else
    printf '0%s\n' "${value:1}"
  fi
}
head=$(git -C "$repository" rev-parse HEAD)
printf 'commit=%s\nstatus_porcelain=\ngenerated proof build log\n' "$head" > "$build_log"
executable_hash=$(hash_file "$executable")
build_log_hash=$(hash_file "$build_log")

write_manifest() {
  cat > "$manifest" <<MANIFEST
commit=$head
clean_head=true
executable_path=$executable
executable_sha256=$executable_hash
build_log_path=$build_log
build_log_sha256=$build_log_hash
MANIFEST
}
write_evidence() {
  local executable_value=${1:-$executable_hash}
  local observed_cohort=${2:-orderedOut}
  local fault=${3:-}
  python3 - \
    "$evidence" "$head" "$executable_value" "$build_log" "$build_log_hash" \
    "$manifest" "$observed_cohort" "$fault" <<'PY'
from pathlib import Path
import json
import sys

(
    evidence,
    head,
    executable_hash,
    build_log,
    build_log_hash,
    manifest,
    observed_cohort,
    fault,
) = sys.argv[1:]
session_id = "generated-proof-session"
records = []


def add(kind, payload=None, correlation_id=None):
    record = {
        "sessionID": session_id,
        "sequence": len(records) + 1,
        "kind": kind,
        "payload": payload or {},
    }
    if correlation_id is not None:
        record["correlationID"] = correlation_id
    records.append(record)


add("configurationBound", {
    "commit": head,
    "level": "floating",
    "ordering": "front",
    "declaredControllerCohort": "orderedOut",
    "repetition": "1",
    "executableSHA256": executable_hash,
    "buildLogPath": build_log,
    "buildLogSHA256": build_log_hash,
    "buildManifestPath": manifest,
})
add("controllerCohortObserved", {"observedControllerCohort": observed_cohort})
for index, command in enumerate(("showOverlay", "hideOverlay", "showOverlay"), 1):
    correlation_id = f"generated-h-{index}"
    add("carbonReceived", correlation_id=correlation_id)
    add("mainDispatchBegan", correlation_id=correlation_id)
    add("commandBefore", {"command": command}, correlation_id)
    add("commandAfter", {"command": command}, correlation_id)
    add("focusImmediate", correlation_id=correlation_id)
    add("focusNextMainRunLoop", correlation_id=correlation_id)
    add("focusDelayed100Milliseconds", correlation_id=correlation_id)
    add("focusDelayed500Milliseconds", correlation_id=correlation_id)
    add("correlationWindowClosed", correlation_id=correlation_id)
if fault:
    supplied = json.loads(fault)
    add(supplied["kind"], supplied.get("payload", {}), supplied.get("correlationID"))
add("sessionEnded")
add("sessionCompletion", {"proofStatus": "valid", "commit": head})
Path(evidence).write_text(
    "".join(json.dumps(record, separators=(",", ":")) + "\n" for record in records),
    encoding="utf-8",
)
PY
}
replace_first() {
  python3 - "$1" "$2" "$3" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
old, new = sys.argv[2:]
text = path.read_text(encoding="utf-8")
if old not in text:
    raise SystemExit("fixture replacement source missing")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
}
expect_rejection() {
  if "$@" >/dev/null 2>&1; then
    echo 'error: provenance fixture was unexpectedly accepted.' >&2
    exit 1
  fi
}
verify_evidence() {
  env \
    PRIVATE_PRESENTER_PROOF_LEVEL=floating \
    PRIVATE_PRESENTER_ORDERING=front \
    PRIVATE_PRESENTER_CONTROLLER_COHORT=orderedOut \
    PRIVATE_PRESENTER_REPETITION=1 \
    "$verifier" --repository "$repository" "$manifest" "$evidence"
}
reject_evidence() {
  expect_rejection env \
    PRIVATE_PRESENTER_PROOF_LEVEL=floating \
    PRIVATE_PRESENTER_ORDERING=front \
    PRIVATE_PRESENTER_CONTROLLER_COHORT=orderedOut \
    PRIVATE_PRESENTER_REPETITION=1 \
    "$verifier" --repository "$repository" "$manifest" "$evidence"
}

# testProvenanceVerifierAcceptsMatchingCleanManifest
write_manifest
"$verifier" --repository "$repository" "$manifest" >/dev/null
write_evidence
verify_evidence >/dev/null

# testProvenanceVerifierRejectsExecutableHashMismatch
cp "$manifest" "$manifest.saved"
wrong_executable_hash=$(different_hex "$executable_hash")
replace_first "$manifest" "executable_sha256=${executable_hash}" \
  "executable_sha256=${wrong_executable_hash}"
expect_rejection "$verifier" --repository "$repository" "$manifest"
mv "$manifest.saved" "$manifest"

# testProvenanceVerifierRejectsBuildLogHashMismatch
cp "$manifest" "$manifest.saved"
wrong_build_log_hash=$(different_hex "$build_log_hash")
replace_first "$manifest" "build_log_sha256=${build_log_hash}" \
  "build_log_sha256=${wrong_build_log_hash}"
expect_rejection "$verifier" --repository "$repository" "$manifest"
mv "$manifest.saved" "$manifest"

# testProvenanceVerifierRejectsCommitMismatch
cp "$manifest" "$manifest.saved"
wrong_head=$(different_hex "$head")
replace_first "$manifest" "commit=${head}" "commit=${wrong_head}"
expect_rejection "$verifier" --repository "$repository" "$manifest"
mv "$manifest.saved" "$manifest"

# testProvenanceVerifierRejectsMissingBuildLog
mv "$build_log" "$build_log.missing"
expect_rejection "$verifier" --repository "$repository" "$manifest"
mv "$build_log.missing" "$build_log"

# testProvenanceVerifierRejectsDirtyTree
printf 'dirty\n' >> "$repository/tracked.txt"
expect_rejection "$verifier" --repository "$repository" "$manifest"
git -C "$repository" checkout -q -- tracked.txt

# testProvenanceVerifierRejectsWrongBuildLogCommit
cp "$build_log" "$build_log.saved"
replace_first "$build_log" "commit=${head}" "commit=${wrong_head}"
build_log_hash=$(hash_file "$build_log")
write_manifest
expect_rejection "$verifier" --repository "$repository" "$manifest"
mv "$build_log.saved" "$build_log"
build_log_hash=$(hash_file "$build_log")
write_manifest

# testProvenanceVerifierRejectsMissingOrDuplicateBuildLogCleanStatus
cp "$build_log" "$build_log.saved"
replace_first "$build_log" $'status_porcelain=\n' ''
build_log_hash=$(hash_file "$build_log")
write_manifest
expect_rejection "$verifier" --repository "$repository" "$manifest"
mv "$build_log.saved" "$build_log"
printf 'status_porcelain=\n' >> "$build_log"
build_log_hash=$(hash_file "$build_log")
write_manifest
expect_rejection "$verifier" --repository "$repository" "$manifest"
python3 - "$build_log" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
path.write_text("\n".join(lines[:-1]) + "\n", encoding="utf-8")
PY
build_log_hash=$(hash_file "$build_log")
write_manifest

# testSameExecutableHashIsRequiredAcrossSmokeAndPhysicalEvidence
write_evidence "$(printf '0%.0s' {1..64})"
reject_evidence

# Cell configuration, cohort, completion, pending state, and permanent overflow
# all fail closed even when the executable/build-log provenance is valid.
write_evidence
expect_rejection env \
  PRIVATE_PRESENTER_PROOF_LEVEL=floating \
  PRIVATE_PRESENTER_ORDERING=front \
  PRIVATE_PRESENTER_CONTROLLER_COHORT=orderedOut \
  PRIVATE_PRESENTER_REPETITION=2 \
  "$verifier" --repository "$repository" "$manifest" "$evidence"
write_evidence "$executable_hash" visibleDesktopSpace
reject_evidence
write_evidence "$executable_hash" orderedOut \
  '{"kind":"recorderFault","payload":{"code":"EVIDENCE_QUEUE_OVERFLOW"}}'
reject_evidence
write_evidence
printf 'pending\n' > "$evidence.pending"
reject_evidence
rm "$evidence.pending"
python3 - "$evidence" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
path.write_text("\n".join(lines[:-1]) + "\n", encoding="utf-8")
PY
reject_evidence
write_evidence
cat >> "$evidence" <<EVIDENCE
{"sessionID":"generated-proof-session","sequence":999,"kind":"sessionCompletion","payload":{"proofStatus":"valid","commit":"$head"}}
EVIDENCE
reject_evidence

# testProvenanceVerifierRejectsIncompleteCorrelation
write_evidence
python3 - "$evidence" <<'PY'
from pathlib import Path
import json
import sys
path = Path(sys.argv[1])
records = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
removed = False
kept = []
for record in records:
    if not removed and record["kind"] == "focusDelayed500Milliseconds":
        removed = True
        continue
    kept.append(record)
for sequence, record in enumerate(kept, 1):
    record["sequence"] = sequence
path.write_text("".join(json.dumps(record) + "\n" for record in kept), encoding="utf-8")
PY
reject_evidence

# testProvenanceVerifierRejectsDuplicateCorrelationEvent
write_evidence
python3 - "$evidence" <<'PY'
from pathlib import Path
import copy
import json
import sys
path = Path(sys.argv[1])
records = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
index = next(index for index, record in enumerate(records) if record["kind"] == "focusImmediate")
records.insert(index + 1, copy.deepcopy(records[index]))
for sequence, record in enumerate(records, 1):
    record["sequence"] = sequence
path.write_text("".join(json.dumps(record) + "\n" for record in records), encoding="utf-8")
PY
reject_evidence

# The WSL-safe runner inventory must be exactly the declared 24-cell product.
matrix="$fixture_root/matrix.tsv"
"$runner" --list > "$matrix"
[[ $(wc -l < "$matrix" | tr -d ' ') -eq 24 ]]
[[ $(LC_ALL=C sort -u "$matrix" | wc -l | tr -d ' ') -eq 24 ]]
[[ $(cut -f1 "$matrix" | LC_ALL=C sort -u | tr '\n' ' ') == 'floating statusBar ' ]]
[[ $(cut -f2 "$matrix" | LC_ALL=C sort -u | tr '\n' ' ') == 'front frontRegardless ' ]]
[[ $(cut -f3 "$matrix" | LC_ALL=C sort -u | tr '\n' ' ') == 'orderedOut visibleDesktopSpace ' ]]
[[ $(cut -f4 "$matrix" | LC_ALL=C sort -u | tr '\n' ' ') == '1 2 3 ' ]]

echo 'M0 proof provenance and 24-cell runner fixture tests passed.'
