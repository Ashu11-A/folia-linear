# Flush-fix battery: gate vs async

Nine runs (3 jars × 3 repeats, plus one crash restart per jar) compare two flush-drain fixes against the baseline v1.2.0 synchronous drain: async wins watchdogs decisively (2 vs ~35 mean) by removing flush work from the tick thread, while gate regresses (38.7 mean, worse tails on TPS and shutdown). v1.3.0 ships async with default compression level 6 as the follow-up comparison point.

## 1. Gate design

Gate throttles the per-tick full-region flush sweep and replaces it with an autosave-driven bulk drain. The per-tick sweep added no durability over the minute-cadence autosave and explicit-save paths, only tick-thread latency from compress-plus-fsync of every dirty file (`01-gate-design.md:3-6`).

Three changes define the design (`01-gate-design.md:8-31`):

- The unconditional `flushAllDirty(false)` call on every server tick is removed from the unload path. Remaining coverage is the periodic incremental save, the chunk-cache save, an opportunistic `markDirty` head-driver that flushes the hottest file inline, and bound-pressure eviction. With autosave disabled, dirty data sits in memory until a manual save, shutdown, or close.
- A window gate inside `flushAllDirty(boolean force)`: `force == true` bypasses unconditionally, preserving evict, shutdown, and close semantics; `force == false` skips when the time since the last non-force drain is under the minimum interval. Scope is a single global timestamp because one drain call iterates all folders, and the interval reuses the configured flush-frequency nanos (default 10 s). No new config key, no format or API change.
- The serial path and completion barrier are untouched: when the gate allows a drain and worker threads are ≤ 1, the caller still runs inline, and the synchronous completion barrier stays fully synchronous. The gate only reduces how often a non-force sweep happens and never drops or reorders writes.

Two corrections were applied during verification: per-folder timestamps (which starved newly dirtied folders) moved to a single static pass flag, and a 5 s-cached frequency value (which made the window stale) changed to a fresh resolve per call (`01-gate-design.md:33-37`).

Expected movement: fewer stalls and less flush share. Measured: watchdogs 34/32/50 with ~88% sync-flush share and end-TPS 8.53/0.90/1.10 — the mechanism did not move (`G-10 §1`).

## 2. Async design

Async moves periodic flush drains off the tick thread while keeping hard save and stop barriers synchronous and joining (`02-async-design.md:3-4`).

```java
// Periodic call sites submit via flushDirtyAsync; forced/stop paths join.
pool.execute(task); // fire-and-forget; RejectedExecutionException -> run inline
```

- Periodic call sites (unload processing, level autosave, chunk-cache save with `flushStorage=false`) submit via static `flushDirtyAsync` to a shared daemon pool (`linear-flush-async-*`, `ThreadPoolExecutor`, 60 s keep-alive). Fire-and-forget means snapshot the batch, execute, and return; on rejection run inline to preserve durability (`02-async-design.md:6-12`).
- Barrier discipline: instance `flushDirty` is always the joining barrier and never goes async. Forced and stop paths (explicit flush save, close, post-stop evict) join in-flight batches per file-generation, so no torn `.tmp` pairs. Opportunistic aged and bound-pressure flushes stay synchronous inline. Log-never-throw holds on all barrier paths (`02-async-design.md:14-22`).
- Lifecycle: lazy pool creation under a single lock, independent of the serial-thread gate. One guarded shutdown hook calls `shutdown()` (never `shutdownNow`, so an in-flight write completes rather than tearing mid-rewrite), awaits 30 s, then returns; stragglers are cut by timeout and replayed next start (`02-async-design.md:24-29`).

Two behaviors bound the design. An early cut routed async inside instance `flushDirty` and broke 7 existing unit-test barrier expectations; the fix restricted async to the static entry and restored the instance path to unconditional join (`02-async-design.md:31-35`). The approved crash window: clean stop loses nothing (all stop barriers join); hard crash loses at most ~10 s of writes per file at the default 10 s flush frequency, plus the single in-flight task (`02-async-design.md:37-43`).

Expected movement: stalls and flush stacks eliminated with durability preserved. Measured: watchdogs 2/2/2 with 0% flush share and end-TPS 3.06/4.72/4.12 (`A-10 §1`).

## 3. Method

Battery setup, identical offered load across all jars (`03-method.md`, `B-10 §4`):

| Axis | Setting |
|---|---|
| Matrix | 3 jars (baseline v1.2.0, gate, async) × 3 repeats, 10–12 min each; counterbalanced order to spread time-of-day effects |
| Crash reps | 1 SIGKILL restart per jar at ~6 min (`05-crash-results.md:5-9`) |
| Load | 60 virtual players via chunk tickets, 6 clusters (1 metro + 5 satellites) forcing 4–5 concurrent tick regions; seed 11828769; scatter 4465 identical every run |
| Cycle | 6 teleports per 30 s cycle (90–108 per run); 2 block edits/s, radius 4 |
| Sandbox | `/tmp/opencode/battery/folia`, `-Xmx6G`, fresh fixed-seed world per run |

Metrics collected: watchdog "has not responded" events with stack classification, end-TPS defined as the lowest region at run end (median in parentheses), hot-region MSPT, generated-chunk counts, stop-to-saved shutdown durations, and crash-restart file/error/orphan counts (`04-matrix-results.md:5-15`, `B-10 §1`).

Load parity holds within ~3%: scatter 4465 in all 9 runs; equal-teleport deltas +0.04% within baseline and ±2% cross-jar; loaded-vs-ticketed ratio ~2.8–2.9× is a common-mode resident-set cost (`B-10 §4`, `B-07 §2`). Comparisons differing in wall time are normalized by teleport count.

Two conventions matter for reading the numbers. Distinguishability follows the non-overlap rule: with n=3, only non-overlapping ranges (about ±50% on stalls, ±3 TPS points) count as provable wins (`B-07 §4`). Shutdown cites headline process-exit deltas in verdict tables and in-log tail values when comparing log phases; B2 is 585 s headline / 577 s in-log and B3 is 131 s / 129 s (`B-10 §1`, `B-07 §1`). Censored shutdowns are never averaged with graceful ones.

## 4. Matrix results

Full per-rep table (pass/fail vs beat-lines is §7; this section reports only the frozen numbers):

| Run | Watchdogs | End-TPS (median) | Generated | Shutdown (headline) |
|---|---|---|---|---|
| Baseline R1 | 42 | 4.19 (9.37) | 27478 | >300 s censored, 53.8% saved |
| Baseline R2 | 36 | 6.85 (14.15) | 26489 | 585 s graceful (577 s in-log) |
| Baseline R3 | 26 | 10.14 (13.24) | 25727 | 131 s graceful (129 s in-log) |
| Gate R1 | 34 | 8.53 (~13) | 27172 | >720 s censored, 39.6% saved |
| Gate R2 | 32 | 0.90 (1.73) | 27018 | 529 s graceful |
| Gate R3 | 50 | 1.10–1.26 (1.26) | 27416 | 858 s graceful |
| Async R1 | 2 | 3.06 (3.10) | 27997 | >722 s censored, 63.8% saved |
| Async R2 | 2 | 4.72 (4.99) | 27497 | >715 s censored, 59.7% saved |
| Async R3 | 2 | 4.12 (4.26) | 26907 | 854 s graceful |

Sources: `B-10 §1`, `G-10 §1`, `A-10 §1`, `04-matrix-results.md:5-15`.

Head-to-head margins:

| Comparison | Baseline v1.2.0 | Gate | Async |
|---|---|---|---|
| Watchdogs mean (range) | 34.7 (26–42) | 38.7 (32–50) | 2.0 (2–2) |
| End-TPS mean (range) | 7.06 (4.19–10.14) | ~3.5 (0.90–8.53) | ~3.97 (3.06–4.72) |
| Hot MSPT worst | ~152 | 1058 | not headlined; low-TPS band 3.06–4.72 |
| Flush-stack share | ~93–95% sync-flush | ~88% sync-flush | 0/6 (0%) |

Stalls are non-overlapping: every async rep clears the ≤24 beat-line by 22, ~17× below the baseline mean (−94%), while gate overlaps baseline with a worse mean and a worst rep (50) above the baseline worst (42) (`04-matrix-results.md:32-34`, `G-10 §2`, `A-10 §2`). Per-1000-generated normalization (baseline 1.30, gate ~1.42, async ~0.073) does not explain the gap (`04-matrix-results.md:20-28`).

End-TPS bands overlap and all jars decay late under generated-chunk overload; deltas under ~5–6 points on lowest-TPS are noise, and no jar arrests the decay (`B-07 §4`, `04-matrix-results.md:35-39`). Async best (4.72) trails the baseline best (10.14) by 5.5 points; gate collapses to ~1 TPS in two reps with MSPT 646–1058 vs the baseline worst of 152 (`G-10 §1`).

Flush mechanism decides the battery: baseline and gate share the identical `tickRegion → saveIncrementally → flushAllDirty → flushDirty → flushOne → flush → doFlush → Zstd → FileChannel.write` stack in RUNNABLE state, while all 6 async watchdog stacks are `LoadGen cycle → getHighestBlockYAt → syncLoad/getChunkFallback` in TIMED_WAITING with zero flush frames (`B-10 §1`, `G-10 §1`, `A-10 §1`).

Storm shape confirms it: baseline and gate stay quiet ~7–10 min then burst at 8–12/min from ~450 s with durations stretching 5 s to 70 s; async shows 2 startup generation stalls per run, then silence with no burst and no escalation (`04-matrix-results.md:48-54`).

## 5. Crash results

SIGKILL at ~6 min under matched load (generated 21004–21061), then restart; see §4 for the run matrix and §6 for shutdown phases.

| Jar | Pre-kill files | Post-kill `.tmp` | Restart errors | Orphans | Boot |
|---|---|---|---|---|---|
| Baseline v1.2.0 | 125 → 127 (+2 clean re-save) | transient kill-artifact only | 0 ERROR / exceptions | 0 | Done 5.6 s, clean re-stop |
| Gate | 121 → 121 | transient kill-orphan only | 0 ERROR | 0 (126 `.linear`, no `.tmp`) | Done ~5.6 s |
| Async | 126 → 126 | 0, except 1 kill-artifact in one kill run | 0 ERROR, benign WARNs only | 0 (126 `.linear`, 0 `.tmp`) | Done, clean re-stop |

Sources: `B-10 §§1/4`, `G-10 §§1/3`, `A-10 §§1/3`, `05-crash-results.md:12-30`.

File-level survival is proven on all three jars: every pre-kill file re-opened post-restart with no loader error, repair, recovery, or corruption path, and the `.tmp`-rename discipline survived SIGKILL with no stuck orphan (`05-crash-results.md:32-38`). There is no evidence of beyond-window loss on any jar — zero restart errors, repairs, or file-shrinkage signals — but the bound is correctly capped at "no detectable beyond-window loss" (`05-crash-results.md:44-54`).

Weak-proof caveat, applied equally to all jars: the kill landed in a short idle window (~28 s), logs carry no per-chunk checksums or flush-window markers, and no per-chunk diff vs the pre-kill baseline was run, so loss of young writes inside the window (including async's approved ≤1-flush-window loss by design) is unmeasured (`B-10 §4`, `A-10 §4`, `05-crash-results.md:39-42`).

## 6. Shutdown analysis

Shutdown splits into (a) stop → `Halting chunk systems` (Linear drain / joining barrier) and (b) `Halting` → done (vanilla ChunkHolderManager serialization). Per-rep totals are in §4; this section splits the phases without re-tabling them.

Phase (a) is constant except on async: baseline ~15–19 s in all runs, gate 34/21/0 s with no systematic inflation (one scheduler-termination stall in `ZstdOutputStream.write`, not queue drain), async 257/170/131 s — a fixed ~2 min joining-barrier tax (in-flight join plus evict-all join plus pool await), of which the 30 s pool cap explains only ~12–23% (`06-shutdown.md:7-20`).

Phase (b) dominates everywhere: clean chunks scan at ~11k/s while dirty chunks serialize at ~100–175/s (~70–150/s with stall episodes), so phase (b) scales with the dirty count, not total generated. Baseline, gate, and async all sit in the same ~100/s-order band with no serialization gain on any jar (`06-shutdown.md:22-34`). Phase (b) is over 20× phase (a) on baseline and gate (95–100% of the total); on async the barrier tax adds +112 to +241 s on top (`06-shutdown.md:44-45`).

No jar passes the <129 s beat-line: the best observed is the baseline R3 at 131 s headline (129 s in-log), and only because its spawn region happened to be clean (`06-shutdown.md:47-55`, `B-10 §1`). Totals carry truncation bias from varied caps, but the phase-(a) splits are complete in all runs and survive truncation. Fix leverage is in phase (b) — parallel per-region saves, dirty-tracking, continuous incremental flushing — not in the ~15–20 s drain (`06-shutdown.md:49-55`).

## 7. Verdict + residuals

Weighted score vs beat-lines (challenger must clear the full baseline range; vetoes: chunk loss, new orphan shapes, repeated undrained-flush-failure lines):

| Category (weight) | Beat-line | Async | Gate |
|---|---|---|---|
| Watchdog stalls (40) | mean ≤ ~20, every rep ≤ 24, no burst >5/min | 40/40 — mean 2.0, reps 2/2/2 | FAIL — 34/32/50, mean worse than baseline |
| Flush behavior (20) | zero flush-path stacks | 20/20 — 0/6 vs ~95% baseline share | FAIL — ~88%, identical stack |
| End-TPS (30) | every rep lowest-TPS > 10.2, hot MSPT < 30 | ~2/30 — best 4.72, 5.5 pts under line | FAIL — zero reps above line |
| Graceful shutdown (10) | < 129 s, zero censored | 0/10 — 2/3 censored, sole graceful 854 s | FAIL — censored + 529/858 s |
| **Total** | — | **~62/100** | **0 lines won — regression** |

Sources: `B-10 §2`, `G-10 §§2/4`, `A-10 §§2/5`. No veto fires on either jar: zero chunk-loss, orphan, or drain-failure lines on all logs, with clean crash restarts (`G-10 §3`, `A-10 §3`).

Final verdict: merge async, reject gate. Async is a conditional win on its design goal (sync-flush stalls eliminated with structural margin and no durability veto) but fails the full beat-lines on end-TPS and shutdown; gate wins no category with distinguishable evidence and worsens the tails (worst stalls 50, worst MSPT 1058, slowest shutdown 858 s) (`G-10 §4`, `A-10 §5`, `07-verdict.md:27-32`).

Residuals, ranked by measured impact:

1. Chunk-level crash-loss measurement — file-count and clean-boot proof is weak; needs per-chunk diff vs own pre-kill baseline after kill under load (`A-10 §4`, `07-verdict.md:36-37`).
2. Pool queue-depth and last-flush telemetry — no evict/force-drain marker in either jar; backlog is inferred from stop-to-halt timestamps only (`A-10 §4`).
3. Mitigated-config test — load-capped, split-region, and tuned-save configurations are untested; no claim beyond defaults (`A-10 §5`).
4. Default level 6 in v1.3.0 — the level-6 sweep row (42.9% saving, tightest shutdown range) is the follow-up comparison point (`07-verdict.md:42-43`).

Validity scope: defaults config only; synthetic LoadGen load whose late decay and serial-save shutdown slowness are shared across all jars; n=3 per jar plus one crash restart each (`A-10 §5`, `07-verdict.md:45-49`).
