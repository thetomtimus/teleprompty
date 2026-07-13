#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: run-m0-phase-a-diagnosis.sh --list
       run-m0-phase-a-diagnosis.sh MANIFEST EVIDENCE_ROOT

The live form runs only on macOS from a clean proof commit. It executes the
exact 24 Phase A cells: 2 levels x 2 ordering modes x 2 controller cohorts x 3
repetitions. In each launch, the operator prepares the declared cohort, enters
Keynote Presenter Display, performs the section 10.2 H sequence, waits for the
correlation window to close, and quits normally. Phase B is not run here.
USAGE
  exit 64
}

emit_cells() {
  local level ordering cohort repetition
  for level in floating statusBar; do
    for ordering in front frontRegardless; do
      for cohort in visibleDesktopSpace orderedOut; do
        for repetition in 1 2 3; do
          printf '%s\t%s\t%s\t%s\t%s-%s-%s-r%s\n' \
            "$level" "$ordering" "$cohort" "$repetition" \
            "$level" "$ordering" "$cohort" "$repetition"
        done
      done
    done
  done
}

if [[ "${1:-}" == '--list' ]]; then
  [[ $# -eq 1 ]] || usage
  emit_cells
  exit 0
fi
[[ $# -eq 2 ]] || usage
[[ "$(uname -s)" == 'Darwin' ]] || {
  echo 'error: live Phase A diagnosis requires macOS; use --list for a WSL-safe matrix audit.' >&2
  exit 1
}
[[ -t 0 || -r /dev/tty ]] || {
  echo 'error: live Phase A diagnosis requires an interactive terminal.' >&2
  exit 1
}

manifest=$(python3 - "$1" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).expanduser().resolve(strict=True))
PY
)
evidence_root=$(python3 - "$2" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1]).expanduser().resolve(strict=True)
if not path.is_dir():
    raise SystemExit("error: evidence root must already exist.")
print(path)
PY
)

manifest_value() {
  local key=$1
  awk -F= -v key="$key" \
    '$1 == key { count += 1; value = substr($0, length(key) + 2) }
     END { if (count != 1) exit 1; print value }' "$manifest"
}

implementation_commit=$(manifest_value commit)
app=$(manifest_value executable_path)
executable_sha256=$(manifest_value executable_sha256)
build_log=$(manifest_value build_log_path)
build_log_sha256=$(manifest_value build_log_sha256)

./Scripts/verify-m0-proof-provenance.sh "$manifest"
if find "$evidence_root" -type f -name '*.pending' -print -quit | grep -q .; then
  echo 'error: evidence root contains a pending file before diagnosis.' >&2
  exit 1
fi

state_root=$(mktemp -d "${TMPDIR:-/tmp}/private-presenter-m0-phase-a.XXXXXX")
trap 'rm -rf "$state_root"' EXIT
completed=0

while IFS=$'\t' read -r level ordering cohort repetition cell_id; do
  before="$state_root/$cell_id.before"
  after="$state_root/$cell_id.after"
  new_paths="$state_root/$cell_id.new"
  find "$evidence_root" -type f \
    \( -name 'overlay-diagnostics.txt' -o -name '*.pending' \) \
    -print | LC_ALL=C sort > "$before"

  printf '\n[%02d/24] %s\n' "$((completed + 1))" "$cell_id"
  cat <<INSTRUCTIONS
Declared controller cohort: $cohort.

After this cold launch, perform this cell exactly:
  1. Select and confirm the private screen in Private Presenter.
  2. Prepare the normal controller as "$cohort":
       visibleDesktopSpace = leave it visible on its ordinary desktop Space;
       orderedOut          = close/order it out before entering Keynote.
  3. Enter a fresh Keynote full-screen Presenter Display.
  4. Press Control-Option-H once for the cold SHOW; wait at least one second so
     immediate/next-run-loop/+100 ms/+500 ms/correlationWindowClosed all record.
  5. Press Control-Option-H once to HIDE; wait at least one second.
  6. Press Control-Option-H once to SHOW; wait at least one second.
  7. Switch to another macOS Space and return to Keynote Presenter Display.
  8. Exit Keynote Presenter Display. Activate Private Presenter only now and
     quit normally with Command-Q; wait for the process to exit.

Do NOT press Control-Option-L, drag, resize, test opacity, or perform Phase B.
The validator requires exactly three complete H correlations and fails closed
for missing/duplicate/unclosed events, cohort/provenance mismatch, pending
publication, overflow, or any permanent invalidation.

Press Return to launch this cold cell.
INSTRUCTIONS
  read -r _ </dev/tty

  if pgrep -x 'Private Presenter' >/dev/null 2>&1; then
    echo 'error: a prior Private Presenter process is still running.' >&2
    exit 1
  fi
  ./Scripts/verify-m0-proof-provenance.sh "$manifest"
  PRIVATE_PRESENTER_EVIDENCE_COMMIT="$implementation_commit" \
  PRIVATE_PRESENTER_PROOF_LEVEL="$level" \
  PRIVATE_PRESENTER_ORDERING="$ordering" \
  PRIVATE_PRESENTER_CONTROLLER_COHORT="$cohort" \
  PRIVATE_PRESENTER_REPETITION="$repetition" \
  PRIVATE_PRESENTER_EVIDENCE_EXECUTABLE_SHA256="$executable_sha256" \
  PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG="$build_log" \
  PRIVATE_PRESENTER_EVIDENCE_BUILD_LOG_SHA256="$build_log_sha256" \
  PRIVATE_PRESENTER_EVIDENCE_BUILD_MANIFEST="$manifest" \
    "$app"
  if pgrep -x 'Private Presenter' >/dev/null 2>&1; then
    echo 'error: the proof app did not terminate normally.' >&2
    exit 1
  fi
  ./Scripts/verify-m0-proof-provenance.sh "$manifest"

  find "$evidence_root" -type f \
    \( -name 'overlay-diagnostics.txt' -o -name '*.pending' \) \
    -print | LC_ALL=C sort > "$after"
  comm -13 "$before" "$after" > "$new_paths"
  new_count=$(wc -l < "$new_paths" | tr -d ' ')
  final_evidence=$(sed -n '1p' "$new_paths")
  if [[ "$new_count" -ne 1 || -z "$final_evidence" || "$final_evidence" == *.pending ]]; then
    echo "error: $cell_id did not publish exactly one new final evidence file." >&2
    exit 1
  fi
  if find "$evidence_root" -type f -name '*.pending' -print -quit | grep -q .; then
    echo "error: $cell_id left pending evidence." >&2
    exit 1
  fi
  PRIVATE_PRESENTER_PROOF_LEVEL="$level" \
  PRIVATE_PRESENTER_ORDERING="$ordering" \
  PRIVATE_PRESENTER_CONTROLLER_COHORT="$cohort" \
  PRIVATE_PRESENTER_REPETITION="$repetition" \
    ./Scripts/verify-m0-proof-provenance.sh "$manifest" "$final_evidence"

  printf '%s\t%s\n' "$cell_id" "$final_evidence" >> "$state_root/completed.tsv"
  completed=$((completed + 1))
done < <(emit_cells)

[[ "$completed" -eq 24 ]] || {
  echo 'error: Phase A diagnosis did not complete exactly 24 cells.' >&2
  exit 1
}
unique_cells=$(cut -f1 "$state_root/completed.tsv" | LC_ALL=C sort -u | wc -l | tr -d ' ')
unique_files=$(cut -f2 "$state_root/completed.tsv" | LC_ALL=C sort -u | wc -l | tr -d ' ')
[[ "$unique_cells" -eq 24 && "$unique_files" -eq 24 ]] || {
  echo 'error: Phase A diagnosis contains a duplicate cell or reused evidence file.' >&2
  exit 1
}

cat "$state_root/completed.tsv"
echo 'Phase A diagnosis produced 24 uniquely configured, provenance-valid cells.'
echo 'STOP: preserve these records and return the causal decision output; do not begin Phase B.'
