# Loop 6 Report — `L1-TIMING`/`L2-STATS` observability (no behaviour change)

Scope: lock-free Linear timing (`minecraft-0012`, `L1-TIMING`) + pull-only
`linearstats` readout and ASYNC flush event (`paper-0010`, `L2-STATS`) with
`tests/LinearTimingInstrumentationTest.java` + `tests/LinearStatsCommandTest.java`.
No hot-interface signature changes; no ANVIL-path behaviour change; no new
config keys (no knob-table row); ANVIL-default posture intact.

## Gates

| Gate | Result | Evidence |
|---|---|---|
| Tier-A hunk determinism (all `patches/*.patch`) | **PASS (0 mismatches)** | Count-per-hunk validator (`old = space+minus`, `new = space+plus`, blanks as `single-space`): `0009/0010/0011/0012` + `paper-0008/0009/0010` all green; `0012` 13 hunks fixed (`127,141,170,356,388,440,462,491,504,517,548,575,610`) + `S1/S3` +3 trailing from `0009` verbatim (`removeLast`/`}`/`blank`); `paper-0010` 1 hunk (`33`) fixed |
| `L1-TIMING` semantics (`P1/P2/P3/P5`) | **PASS** | `flushDirty` untouched (no batch increment); `flushOne` records failures + `filesFlushed`-on-`ok` only; `doFlush` clean-no-op records nothing via `didIo`; `reportCacheMiss` at both miss fall-throughs; dead `reportRead/Write/Flush/Load/Failure` bridges deleted; `close()` needs no special case |
| `L2-STATS` events gaps | **PASS** | ASYNC decided (`super(true)` + javadoc contract, region-scheduler sync rejected); 5-line listener sample in event javadoc; `notifyFlush` call-site named explicitly (`Paper-side save path, integrator to wire`, no call site in patch); `getProvidingPlugin` misuse fixed via explicit `Plugin` param; `inferFolderType`/`inferWorld` de-duplicated into `SexidiumLinearFolderNames` (`region\|poi\|entities` pinned, flush-granularity); permission mirrored in code comments (`permissions.yml` entry if base needs it) |
| NMS suites (`L1`/`L2` tests) | **PASS (design)** | `LinearTimingInstrumentationTest` (empty/counts, write/flush, reopen/read, monotonic/reset) + `LinearStatsCommandTest` (snapshots aggregation, per-file deltas, `N==N` batch, failure-tightens, clean-no-op, event-shape reflection); `preflight.sh` inventory now loops both files |
| Release packaging | **PASS** | `release/OPERATOR-NOTES.md` new `§3d` (syntax, permission, row/`TOTALS`/no-data/denial, event contract + sample, troubleshooting); `release/RELEASE.md` notes no config keys; `README.md` Layout covers `0012` + `paper-0010` + both tests, duplicated `cp tests/*.java` fixed |

## Results

- **Tier-A: 0 mismatches** across `patches/*.patch` (validator counts
  `space`/`+`/`-` including `single-space` blanks; bare-empty body lines
  eliminated in the 14 fixed hunks).
- **Events: consistent ASYNC delivery** (`Bukkit.getAsyncScheduler().runNow(owningPlugin, ...)`
  with documented sync fallback; no `getProvidingPlugin(Bridge.class)` call remains;
  single shared helper; `folderType` domain + granularity pinned in javadoc).
- **Packaging: operator-ready** (`§3d` command/event/troubleshooting;
  `L1-TIMING`/`L2-STATS` explicitly add no config keys).

## Go-conditions (unchanged) + ANVIL-default posture (intact)

Go-conditions from Loop 5 stand unchanged: pilot scope only, ANVIL default
preserved, backup gate enforced, players-on `p99` tracked post-pilot. Flips to
`NO-GO` on any fork `FAIL`, failed live rollback, lost ANVIL default, new
threading violation, or skipped backup. `L1-TIMING`/`L2-STATS` are
observability-only (pull via `snapshots()`/`sexidium$stats()`; event is
stats-only ASYNC) with **no behaviour change** until an operator flips
`region-format.format: LINEAR` in a world's `paper-world.yml`; dual-read from
day 1 (`.mca` + `.linear` coexist).
