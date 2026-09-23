# Level 03 — baseline × 3 + rc2 × 3 + 2 SIGKILL rows — IN PROGRESS

- `test=3` `level_confirmed=3` (3-source: config `compression-level: 3` in `paper-world-defaults.yml` + header audit 8383/8383 lvl=3 at offset 17 + 0 `[region-format]` fallback lines; baseline panel has no `lvl` token per paper-0010, rc token pending)
- `jar=baseline` `jar_sha256=e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (60532041 B, shadow-server + stress/jars identical)
- `jar=rc2` `jar_sha256=b0ea20484d85e4adce697cb786bf164b6fa4865d9eb122b8c931910e2723e1d6` (60541066 B, stress/jars folia-rc.jar + folia-rc2.jar identical sha)
- `ldm=0` `flush_threads=1` `compression_workers=0` (axis-1 defaults)
- `bytes_anvil=26056405704` (frozen constant, S2-finalize 2026-09-22; NOT re-derived, source-anvil read-only)
- `convert_s=724` (t0 07:02:17Z→t1 07:14:21Z; per-dim walls 643.0+11.4+61.1=715.5s, threads 3/1/1, empty `level-3/` dir, ≤8 threads)
- `bytes_on_disk=17213566501` (≈16.03 GiB; OW 16769212135 + nether 165033691 + end 279320675; per-folder `du -sb`, manifests excluded; ratio vs Anvil 0.6607, 33.93% saved; saved vs #1 3.30%)
- Conversion (`mca2linear -c 3` per-dim via `worker-1` python3): OW 7382 files in=23318872064 out=16769212135 ratio=0.719 wall=643.0s; nether 117 files in=274874368 out=165033691 ratio=0.600 wall=11.4s; end 884 files in=2462646272 out=279320675 ratio=0.113 wall=61.1s; all `EXIT=0`, `DONE-ALL`; 0 `.mcc`; free 28G→12G (floor 12≥8 PASS)
- Verify (decode-back workaround, harness `verify_level` broken by construction): header audit 8383/8383 lvl=3 bad=0 (offset 17, `>QBQbhI` field 4); manifest src_sha cross-check 7382+117+884=8383/8383 mism=0 missing=0 (`level-3` convert.manifest `src_sha` == `source-anvil` decode `dst_sha`, joined on `.mca` rel); forceload-subset (16 files) `linear2mca` + `verify` per-dim 12/2/2 files all `total diffs=0`; full-tree decode-back NOT attempted (needs ~23G temp, free 12G — would breach floor; manifests + headers + subset are the honest gate; temp subset dirs wiped)
- Pristine: 16 files (OW 4×(region+entities+poi)=12 + nether 2 + end 2) 29M + `pristine.sha256` 16 lines; `EXPECTED.json` 6144 keys (edit-workload.py gen --level 3, sha scheme verified) + `commands-y319.txt` 6144 setblocks + `commands.txt` copy staged (mirror `level-3/`)
- Staging (move, not copy — same `/dev/sda6`, rename instant, free 12G): backed up small world (1060488 B + 3 configs) to `level-3/smp-test-small-backup`; moved 8 dirs `level-3/tree/{dims}/{region,entities,poi}` → `smp-test/.../dimensions/minecraft/...` (world region counts OW 2502 / nether 64 / end 676); `TREE` left with manifests only; set `compression-level: 3`, `log-flush-batches: true`; appended NMT to `sexidium-node.args`
- Smoke boot baseline 07:16:35Z `Done (10.288s)`, 0 fallback lines, config-readback level 3 → `level_confirmed=3`; console live-fire `linearstats` → `{"ok":true}` + baseline panel (9 folders, plain `dirtyDepth`, C4 as expected)

## Runs (IN PROGRESS — 1/8: baseline b1 done, b2+b3 + 3 rc + 2 kills pending)

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 (cold-ish) | 9.9 | 354.5 (per-chunk; 6144/6144 Changed; C1+C2 recipes; stale head-start caveat) | n/a (never-invoked; 90s cap, 0 movement; 03-H2/H3) | -/- (baseline absent, correct) | 56 | 83.3 | 143/0 | -1 (mspt-no-response; 91 polls, 0 pairs) | heap 1616/2872, rss 5411/6137, nmt 6515, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 12→12 (no breach) |

CSVs: 1 row appended (test=3 baseline run 1); sidecars in mirror `samples/3-baseline-1/` (26 files, mem-series 836). Per-run wipe done (logs/cache only, tree stays in `smp-test` volume); `free_after_wipe_gib` corrected `-1→12` (df transport was worker-1-down, not a missed wipe — `logs/` verified empty 07:41Z; df now via worker-2).

Medians (renderer-computed; warm medians for boot/load per agent 32 §6):
`n/a — n=1 baseline provisional (NOT a level verdict)`

## Evidence (run b1)

- Boot: start 07:17:24Z → `Done (9.945s)`; 0 `[region-format]` lines (healthy, no fallback); config-readback level 3 + headers 8383 lvl=3 → `level_confirmed=3`; `jar_sha256` e609c1d4 (shadow, untouched since L1 close-out); `smp1_players=0` (live-log read, no live command); `started_at=2026-09-23T07:17:21Z`
- Load: forceload 24-add C1 recipe → query **4096/1024/1024 exact**; pass 1 staged 6144 EDITs in 21×300 batches → `load_s=354.5` (acks 6144/6144 from batch 6 — stale head-start from prior-run log tails in the cumulative 20000-line scan, same caveat as L1 b2/b3; exact batch delivery proven by 21/21 BATCH_DONE); pass 2 redirty identical setblocks → all 21 BATCH_DONE, `load_s=-256.1` DISCARDED by design (pass-2 timing never enters CSV); `load_evidence=per-chunk`
- Age-wait (autosave-watch, run-1 baseline): 15s + 65s, flush 0→0 + dirty 55→55 → `autosave_reaches_flush=false` (S1 reproduced on L3: steady-state no-flush on baseline)
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line; pre dirty 55 + W>0, post 2 reads (5s + 30s) zero movement (`flush` 0→0) → `save_all_s=n/a (never-invoked)` per spec 33 §7 (cite 03-H2, 03-H3, 02-Unknowns); C3 reproduced on L3
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5)
- Shutdown: SIGTERM → exit = **83.3s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (`Stopping server`, `Saved all worlds`, `All RegionFile I/O tasks`); dirty_at_stop 56; 0 `Failed to flush`. Under 96 (no trigger)
- Tick: 91 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as L1 b2/b3/runs; sidecars `mspt.txt` + `tick-series-*.json` 0 pairs + `tick-cooked.json`)
- Mem: 836 samples ~1Hz: heap steady **1616** / peak **2872**; rss steady 5411 / peak (HWM) 6137; **nmt committed peak 6515** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill (95% guard flagged throughout, flag only — same as L1 precedent)
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs staged EXPECTED-3 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`** (`verify.json` in mirror). `flush_failures=0`; `level_fallback_severe=0`
- Disk: `free_before_gib=12` → `free_after_wipe_gib=12` (corrected, see above; floor 12≥8 holds, abort <8 never triggered)

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS (b1 only, n=1 — NOT a level verdict)` — shutdown 83.3s <96 (no trigger); cgroup 6144.0 = 100% cap → WARN-side `peak>=85%` datum when renderer runs (same as L1). No ❌ (exit 143, 0 lost, 0 failures, 0 OOM, fallback 0). STOP+REPORT triggers: none (floor 12≥8 holds, level_confirmed=3, no ❌) — CONTINUE to b2.

## Blockers / anomalies

- **Live incident (not mine, read-only observed): ~07:38:23–07:39:01Z proxy + lobby + worker-1 stopped with clean graceful shutdowns** (coordinated, operator-side; smp-1 alive, 0 players). Impact on L3: worker-1 (console/df host) down → b1's `clean_run` df + `stop_check` df failed (`free=-1` → driver STOP exception AFTER the row was recorded; CSV `free_after_wipe_gib=-1`, corrected to 12). Recovery (no live mutation): console + df moved to worker-2 (smc.py/smc_batch.py staged, shas verified; `C.WORKER=P.WORKER="worker-2"` in l3run.py); live containers NOT restarted (read-only rule). smp1_players=0 throughout.
- C6 future-skipped=0 all batches (no midnight crossing). No `level_fallback_severe`, no ❌, no OOM kill (cap touched 100% on b1, reclaimed, exit 143), no floor breach (12≥8; 8G waiver holds), no live writes (only `stress/level-3/*` + `smp-test` volume via host volume paths + container execs; `smp-1` untouched). `run-queue.json` left `done:["1"]` (NOT complete — 1/8 runs).

## Evidence

- Pre-run gates verified 2026-09-23 (all read-only unless noted):
  - `smp-test` container PRESENT but STOPPED (L1 close-out state); logs readable; no exec (409 not-running, expected).
  - Free: **28 GiB** (`df --output=avail -B1G /srv/build` via worker-1) ≥ 17+5 GiB need, ≥ 8 GiB floor → PASS. Abort <8G armed.
  - Lock: standing `sleep 200000` reservation (PID 3159562, since 11:25Z Sep-22) holds `stress/harness.lock`; no active driver (no mca2linear/l1run/l3run/p0run on host), no converter contention → one-run rule satisfied under L1 precedent (no second lock, no break).
  - Jars on host: `stress/jars/folia-baseline.jar` e609c1d4 ✓, `folia-rc.jar` + `folia-rc2.jar` b0ea2048 ✓ (identical).
  - Shadow jar: baseline e609c1d4 ✓ (L1 close-out restored). Small world 1046710 B ✓. Config `compression-level: 6` + `log-flush-batches: false` (L1 close-out) — set to 3/true at staging.
  - Patched plugin `sexidium-paper-26.1.2+16.jar` 21997aad ✓. NMT absent (L1 reverted) — re-add at staging, revert at close-out.
  - Console path: `worker-1:/tmp/smc.py` sha `bff98d8c…` == fork `bench/smc.py` ✓; `smc_batch.py` staged ✓; `nbtlib` 2.0.4 on worker-1 + local ✓.
  - smp-test volume NMT/config/plugin verified via host volume paths (sudo -S, read-only).
  - source-anvil intact (overworld/the_nether/the_end + convert.manifests); converter `/srv/build/repo/scripts/vendor/mca2linear-convert.py` present; `convert.lock/` empty.
  - Workload artifacts generated offline (local): `level-3/EXPECTED.json` 6144 keys (edit-workload.py gen --level 3, y=319 OW per C2) + `commands-y319.txt` 6144 setblocks + `commands.txt` copy; sha scheme `sha256("dim|cx|cz|mat|level")` level=3 verified on 2 sample keys.
  - Driver `loop4-P0-mirror/l3run.py` (from `l1run.py`: LEVEL=3, staged L3 EXPECTED, b1 target added, k_boom/k_room disabled per C7 charter, tags `3-*`); py_compile OK.
  - `smp1_players` via live-log read only (no live commands). Live stack untouched.
- Calibrations reused from L1 (level-01.md, NOT re-derived): C1 forceload 24-add block-coord recipe (256-chunk limit); C2 OW y=319 (already in edit-workload.py DIM_Y); C3 save-all no-op → capped poll + §7 movement rule; C4 baseline panel no lvl/p50/p99 (config+headers confirm); C5 header level byte at offset 17 (`>QBQbhI` field 4; harness `confirm_level_disk` reads d[8]=VERSION — report, not fix); C6 exclude future-dated acks (midnight-rollover guard in parse_feedbacks + tick sampler); C7 scoped-cgroup OOM uninducible 2G→128M — NO OOM attempts on L3 (SIGKILL-only kills).

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS — no rows` — conversion pending. STOP+REPORT triggers armed: floor breach (<8G), level_confirmed≠3, any SIGTERM ❌.

## Blockers / anomalies

- None. OOM rows excluded by charter (C7). EDIT-600 eviction NOT in charter L3 (skip — base 6144 only).
