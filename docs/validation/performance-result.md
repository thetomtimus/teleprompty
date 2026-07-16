# Private Presenter M5 exactly-50,000-word performance result

Status: PENDING
M5 WSL source candidate
Source SHA: PENDING
Executable SHA-256: PENDING
Host: PENDING
Mac model / chip / RAM: PENDING
macOS: PENDING
Xcode: PENDING
Swift: PENDING
Release flags: PENDING
Scale / refresh: PENDING
Power / thermal state: PENDING
Fixture SHA-256: PENDING
Pristine snapshot SHA-256: PENDING
Load trials: PENDING
Edit latency distribution / p95 / maximum: PENDING
Main-thread stalls: PENDING
Reader replacement / resync counters: PENDING
Save and final revision: PENDING
Memory samples / OLS slope / end delta: PENDING
Local Instruments trace paths: PENDING
External content-neutral Instruments record: PENDING
Same executable + pristine snapshot + fresh-process relaunch: PENDING
Normal disposable-account store reset: PENDING
Time Profiler duration samples: PENDING
Allocations live-byte samples (not processFootprintBytes): PENDING
M3 native evidence: PENDING
M4 native evidence: PENDING
Promotion gate: external exact source/app SHA only

This additive record contains no Release, Instruments, latency, memory, hardware, or physical
result. Populate content-neutral measurements only after the exact source and executable identities
have completed the approved baseline-Mac protocol. Keep the synthetic fixture and raw traces
untracked; never include lecture text, title, selection, display identity, user path, or user ID.

The absolute tests must be launched with all three gates; opt-in alone is insufficient:

```text
PRIVATE_PRESENTER_M5_BASELINE=1
PRIVATE_PRESENTER_M5_SOURCE_SHA=<exact 40-character checkout SHA>
PRIVATE_PRESENTER_M5_EXTERNAL_INSTRUMENTS_RECORD=<absolute local JSON path>
```

The untracked JSON is schema version 1 and contains only content-neutral identities, protocol
booleans, three load durations, 300 edit durations, main-thread stall durations, five allocation
sample minutes, and five Instruments Allocations live-byte samples. The validator rejects extra
fields, `phys_footprint`, and `processFootprintBytes`; the latter remains a provisional in-process
diagnostic and can never satisfy an absolute memory gate.
