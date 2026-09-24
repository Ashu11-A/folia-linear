# Level 12 — baseline × 3 + rc2 × 3 + 2 SIGKILL rows — IN PROGRESS

- `test=12` `level_confirmed=12` (3-source: config `compression-level: 12` in `paper-world-defaults.yml` + header audit 8383/8383 lvl=12 at offset 17 + 0 `[region-format]` fallback lines; baseline panel has no `lvl` token per paper-0010, rc token pending)
- `jar=baseline` `jar_sha256=e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (60532041 B, host `stress/jars/folia-baseline.jar` + shadow-server identical, verified 2026-09-24)
- `jar=rc2` `jar_sha256=b0ea20484d85e4adce697cb786bf164b6fa4865d9eb122b8c931910e2723e1d6` (60541066 B, host `stress/jars/folia-rc2.jar`, verified 2026-09-24)
- `ldm=0` `flush_threads=1` `compression_workers=0` (axis-1 defaults)
- `bytes_anvil=26056405704` (frozen constant, S2-finalize 2026-09-22; NOT re-derived, source-anvil read-only)
- `convert_s=968` (t0 01:03:07Z→t1 01:19:15Z; per-dim walls 879.4+15.5+62.7=957.6s, threads 4/2/2, empty `level-12/` dir, ≤8 threads)
- `bytes_on_disk=14182988894` (≈13.21 GiB; OW 13854576161 + nether 134403523 + end 194009210 out-bytes; per-folder `du -sb` minus manifests 2270364; ratio vs Anvil 0.5443, 45.57% saved; saved vs #1 20.33%)
- Conversion (`mca2linear -c 12` per-dim via host helper `level12-convert` on bind-mounted build volume, python:3.13-slim + pyzstd): OW 7382 files in=23318872064 out=13854576161 ratio=0.594 wall=879.4s; nether 117 files in=274874368 out=134403523 ratio=0.489 wall=15.5s; end 884 files in=2462646272 out=194009210 ratio=0.079 wall=62.7s; all `EXIT=0`, `DONE-ALL`; 0 `.mcc`; free 27G→14G (floor 14≥8 PASS)
- Verify (decode-back workaround, harness `verify_level` broken by construction): header audit 8383/8383 lvl=12 bad=0 (offset 17, `>QBQbhI` field 4); manifest src_sha cross-check 7382+117+884=8383/8383 mism=0 missing=0 extra=0 (`level-12` convert.manifest `src_sha` == source-anvil decode `dst_sha`, joined on `.mca` rel); forceload-subset (16 pristine files) `linear2mca` + `verify` per-dim 12/2/2 files all `total diffs=0` (temp mini dirs wiped)
- Pristine: 16 files (OW 4×(region+entities+poi)=12 + nether 2 + end 2) + `pristine.sha256` 16 lines; `EXPECTED.json` 6144 keys (edit-workload.py gen --level 12, sha scheme `sha256("dim|cx|cz|mat|level")` verified on sample key) + `commands-y319.txt` 6144 setblocks (4096 OW @319, zero 320) + `commands.txt` copy staged (mirror `level-12/`)
- Staging (move, not copy — same `/dev/sda6`, rename instant): backed up small world + configs to `level-12/smp-test-small-backup`; moved 8 dirs `level-12/tree/{dims}/{region,entities,poi}` → `smp-test/.../dimensions/minecraft/...` (world region counts OW 2502 / nether 64 / end 676); `TREE` left with manifests only; set `compression-level: 6→12`, `log-flush-batches: false→true`; appended NMT to `sexidium-node.args`. Explicit per-dim `mv` commands (single-quoted SSH, no loop vars — L6 staging lesson honored)
- Smoke boot baseline `Done (10.746s)`, 0 fallback lines, config-readback level 12 → `level_confirmed=12`; console loopback `linearstats` → baseline panel (dirty 0, C4 as expected); smc.py `bff98d8c` + smc_batch.py `a2b7376b` (persisted L6 layer, shas re-verified); clean SIGTERM stop (143) afterwards, container STOPPED for b1

## Runs (STOPPED — 4/8 rows: axis 3/6 baseline + r1 ❌; NO FURTHER RUNS — see verdict)

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 (cold-ish) | 10.1 | 352.5 (per-chunk; batched driver 21×300, staged EDITs; 6144/6144 acks EDITLOG-1+2; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 82.2 | 143/0 | -1 (mspt-no-response; 100 polls, 0 pairs) | heap 1248/2896, rss 5325/6139, nmt 6467, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| b2 (warm) | 10.7 | 352.1 (per-chunk; batched driver 21×300, staged EDITs; fresh +300/batch growth to 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 84.3 | 143/0 | -1 (mspt-no-response; 95 polls, 0 pairs) | heap 1436/3072, rss 5384/6116, nmt 6497, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| b3 (warm, last baseline) | 10.3 | 354.2 (per-chunk; batched driver 21×300, staged EDITs; fresh 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 56 | 85.2 | 143/0 | -1 (mspt-no-response; 96 polls, 0 pairs) | heap 2788/3072, rss 5268/6146, nmt 6517, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| r1 (rc ❌) | 10.1 | 352.2 (per-chunk; batched driver 21×300, staged EDITs; fresh +300/batch to 6144 at batch 11; C6 future-skipped=0) | 121.3 (COMPLETED — first completion in campaign; movement=true via stats-reset 9→0, see anomaly) | 0.0/0.0 (ANOMALOUS ZEROS — post-save panel server-rendered files=0/never-flushed; presave+prestop normal 1000/1000) | 55 | 120.9 ❌ | 137/0 (SIGKILL after 120s grace, NOT OOM) | -1 (mspt-no-response; 104 polls, 0 pairs) | heap 1366/3050, rss 5339/6142, nmt 6523, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 2047/6144 (all missing, S2 tail-loss) | 14→14 (no breach) |

## Run b1 (cold-ish)

baseline run 1 done: boot=10.142 load=352.5 save=-1 shut=82.2 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0

## Evidence (run b1)

- Boot: restore 01:27Z (16/16 sha OK, double restore: pre-run unmeasured-stop restore + `run_axis` restore) → start → `Done` → `boot_s=10.142`; baseline plain panel + config 12 + 0 fallback → `level_confirmed=12` (patient-linearstats: loopback console); `smp1_players=-1` (live STOPPED by owner, no live-log lines — honest unknown); `started_at=2026-09-24T01:27:12Z`
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (asserted in-driver); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=352.5` (EDITLOG-1 6144 keys; exact batch delivery proven by 21/21 BATCH_DONE asserted in-driver + 0-lost verify below; C6 future-skipped=0); pass 2 redirty identical setblocks → EDITLOG-2 6144 keys, pass-2 timing DISCARDED by design
- Age-wait (autosave-watch, run-1 baseline): 15s + 65s, flush 0→0 + dirty 54→54 → `autosave_reaches_flush=false` (S1 reproduced on L12: steady-state no-flush on baseline)
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line; movement=false → `save_all_s=n/a (never-invoked)` per spec 33 §7 (cite 03-H2, 03-H3, 02-Unknowns); C3 reproduced on L12
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5)
- Shutdown: SIGTERM → exit = **82.2s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 54; 0 `Failed to flush`. Under 96 (no trigger)
- Tick: 100 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as L1/L3/L6/L9)
- Mem: 955 samples ~1Hz: heap steady **1248** / peak **2896** (under Xmx 3072 — NOT saturated); rss steady 5325 / peak (HWM) 6139; **nmt committed peak 6467** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only, same precedent)
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs staged EXPECTED-12 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`** (`verify.json` in mirror). `flush_failures=0`; `level_fallback_severe=0`
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds)
- Sidecars: mirror `samples/12-baseline-1/` 26 files (EDITLOGs, EXPECTED×2, panels incl. autosave-watch, stats, mem-series 955, tick-series, verify, tail-stop) — driver writes mirror-direct, no separate sync needed

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS (b1 only, n=1 — NOT a level verdict)` — shutdown 82.2s <96 (no trigger); cgroup 6144.0 = 100% cap → WARN-side `peak>=85%` datum when renderer runs (same as L1/L3/L6/L9). No ❌ (exit 143, 0 lost, 0 failures, 0 OOM, fallback 0). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=12, no ❌) — CONTINUE to b2.

## Run b2 (warm)

baseline run 2 done: boot=10.708 load=352.1 save=-1 shut=84.3 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0

## Evidence (run b2)

- Boot: restore (16/16 sha OK, double restore: pre-run unmeasured-stop restore + `run_axis` restore) → start → `Done` → `boot_s=10.708`; baseline plain panel + config 12 + 0 fallback → `level_confirmed=12` (patient-linearstats)
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=352.1` (fresh +300/batch growth batches 9–11, 6144 at batch 11 — cleanest provenance of the level so far; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design
- Settle: 60s (run 2, no autosave-watch — watch is run-1-per-jar only)
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line; movement=false → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced b1+b2)
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5)
- Shutdown: SIGTERM → exit = **84.3s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 54; 0 `Failed to flush`. Under 96 (no trigger)
- Tick: 95 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as b1)
- Mem: 896 samples ~1Hz: heap steady **1436** / peak **3072** (= Xmx, saturated, no ExitOnOOM — exit 143 proves it); rss steady 5384 / peak (HWM) 6116; **nmt committed peak 6497** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only)
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-12 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds)
- Sidecars: mirror `samples/12-baseline-2/` (EDITLOGs, EXPECTED×2, panels, stats, mem-series 896, tick-series, verify, tail-stop, runner log `l12-b2.runner.log`) — driver writes mirror-direct

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS (baseline n=2 provisional — NOT a level verdict)` — shutdown median 83.3s (82.2, 84.3) <96 (no trigger); cgroup 6144.0 = 100% cap → WARN-side `peak>=85%` datum (same as L1/L3/L6/L9). Load 352.5→352.1 (b1 cold-ish excluded from warm medians per §5; single warm datum 352.1s so far). No ❌ (both exits 143, 0 lost, 0 failures, 0 OOM, fallback 0). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=12, no ❌) — CONTINUE to b3.

## Run b3 (warm, last baseline)

baseline run 3 done: boot=10.304 load=354.2 save=-1 shut=85.2 exit=143 lost=0/6144 dirty=56 tick=-1 cgroup_peak=6144.0

## Evidence (run b3)

- Gates re-verified: free **14 GiB ≥ 8 floor** (abort <8 never triggered); lock = standing `sleep 200000` reservation (precedent: no second lock, no break); jar baseline `e609c1d4` (shadow + node, 60532041 B); config `compression-level: 12` + globals threads 1/workers 0/LDM 0/freq 10/log-batches true; NMT **ON**; pristine 16/16 sha OK (double restore); EXPECTED-12 6144 keys + `commands-y319.txt`; patched plugin `21997aad`; `smp1_players=-1` (live STOPPED by owner, no live-log lines — honest unknown); `nbtlib` local.
- Boot: restore → start → `Done` → `boot_s=10.304`; baseline plain panel + config 12 + 0 fallback → `level_confirmed=12` (patient-linearstats).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=354.2` (batch-11 acks 6144 fresh, +300/batch proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design.
- Settle: 60s (run 3, no autosave-watch — watch is run-1-per-jar only).
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line; movement=false → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced b1+b2+b3).
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5).
- Shutdown: SIGTERM → exit = **85.2s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 56; 0 `Failed to flush`. Under 96 (no trigger).
- Tick: 96 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as b1/b2).
- Mem: 910 samples ~1Hz: heap steady **2788** / peak **3072** (= Xmx, saturated, no ExitOnOOM — exit 143 proves it); rss steady 5268 / peak (HWM) 6146; **nmt committed peak 6517** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-12 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`** (`verify.json` in mirror `samples/12-baseline-3/`). `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds).
- Sidecars: mirror `samples/12-baseline-3/` (EDITLOGs, EXPECTED×2, panels, stats, mem-series 910, tick-series, verify, tail-stop, runner log `l12-b3.runner.log`) — driver writes mirror-direct.

## Baseline FINAL medians (3/3) + provisional verdict

- Baseline FINAL (n=3): `lvl 12, n=3, WARN, shutdown 84.3s, why=peak>=85%` (renderer). Boot warm median 10.5s (b2 10.708 + b3 10.304; b1 cold-ish 10.142 excluded); load warm median 353.2s (b2 352.1 + b3 354.2; b1 352.5 calibration excluded); shutdown median 84.3s (82.2, 84.3, 85.2); dirty median 54 (54,54,56); lost 0+0+0; exits 143×3; flush p50/p99 absent (correct); save n/a ×3; tick -1 ×3; cgroup 6144.0 (100% cap, reclaimed, no OOM).
- vs L1/L3/L6/L9 baselines: shutdown 84.3s vs 80.0 (L1) / 80.3 (L3) / 74.4 (L6) / 77.2 (L9) — highest so far, still <96; dirty 54 same as L6/L9; load 353.2 identical (decode-independent as expected); lost 0/6144 all runs.
- `WARN (baseline FINAL n=3 — axis half COMPLETE)` — no shutdown trigger (84.3 <96); no ❌. Level verdict PENDING (need 3 rc + 2 kills). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=12, no ❌) — CONTINUE to r1 (first rc: swap shadow→rc2 b0ea2048 via `swap_jar` on rc1 ONLY).

## Run r1 (rc, autosave-watch) — ❌ STOP 2026-09-24 03:02Z→03:29Z (driver `loop4-P0-mirror/l12wrap.py rc1`, FIRST rc run — jar swap baseline→rc2 included; loopback console)

- Swap (rc1 only): host-fetch rc2 `CACHED b0ea20484d85` (jars pre-staged, no egress) → `sha256sum -c` `rc.jar: OK` → cp to shadow + node jars → swap-boot (ATTRIBUTION: `swap_jar` cps AFTER start, so the swap-boot Done belongs to the pre-swap baseline boot — same ordering bug as L1/L6/L9 r1; the true rc boot is the AXIS `boot_s=10.103`). Live stack untouched (live stays STOPPED by owner).
- Gates re-verified: free **14 GiB ≥ 8 floor** (abort <8 never triggered, 14→14); lock = standing `sleep 200000` reservation (precedent: no second lock, no break); config `compression-level: 12` + globals threads 1/workers 0/LDM 0/freq 10/log-batches true; pristine 16/16 sha OK (double restore); EXPECTED-12 6144 keys + `commands-y319.txt`; patched plugin `21997aad`; NMT **ON**; `nbtlib` local.
- Boot: restore → start → `Done` → `boot_s=10.103`; rc panel `lvl 12` on all 3 dims + 0 `[region-format]` fallback → `level_confirmed=12` (spec 32 §4 rc source).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=352.2` (batch-1 acks 3188 head-start, +300/batch to 6144 at batch 11 proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design.
- Age-wait (autosave-watch, run-1 rc): 15s (rc age gate) + 65s, flush 9→9 + dirty 54→54 → `autosave_reaches_flush=false`. Periodic age-flush (m0017) did NOT move counters in this settle window — same as L9 r1.
- Save-all (FIRST COMPLETION IN CAMPAIGN + STATS-RESET ANOMALY): `save-all flush` POST → `{"ok":true}`; completion line found at **121.3s** → `save_all_s=121.3` with `movement=true`. BUT the movement is `flush_before=9 → flush_after=0`: the post-save panel (03:15:11, server-rendered) shows ALL folders `files=0`, `dirty 0/512`, `never flushed`, p50/p99 0us — counters ZEROED. Presave (03:11:44) showed real data (dirty 13+1+16+3…, p50/p99 50ms–1.00s) and prestop (post-redirty) is normal again (dirty 55, 1000/1000). No second `Done`, no `Stopping`, no OOM, no crash in the 3000-line tail window — stats zeroed WITHOUT restart. OPEN QUESTION (Loop-5 input): what resets Linear stats during a level-12 save-all drain. The completion itself is real (timed line match with stale-guard), but the 9→0 movement is NOT a save-all effect in the §7 sense — recorded honestly as measured.
- Flush: post-save panel anomalous zeros → CSV `flush_p50_ms=0.0`, `flush_p99_ms=0.0` (parser faithfully read server-rendered zeros; NOT -1-absent, NOT 1000/1000 — flagged, not silently bucketed). Prestop panel normal (1000/1000, dirty 55).
- Shutdown ❌: SIGTERM → drain crossed the 120s grace → **exit 137, `OOMKilled=false`** (docker wait BEFORE step-7 restart) → `shutdown_s=120.9`. Tail: single `Stopping server` 03:21:57, RegionShutdownThread drain lines 03:21:57/03:23:36, NO clean markers, 0 `Failed to flush`, no fallback SEVERE. This is H3 reproduced on rc at level 12: serial drain of 55 dirty files at level 12 exceeds `stop_grace_period`.
- Confirmation (park stop, unmeasured, no data at stake): post-verify idle server SIGTERM-stopped → **121.0s / 137 / oom 0** — second consecutive SIGTERM→SIGKILL. Level-12 shutdown ≥120s is 2/2 reproducible (r1 with dirties + idle park on post-kill tree). Container left STOPPED.
- Tick: 104 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as all prior runs).
- Mem: 990 samples ~1Hz: heap steady **1366** / peak **3050** (under Xmx, NOT saturated); rss steady 5339 / peak (HWM) 6142; **nmt committed peak 6523** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill (`oom_killed=0` — the 137 is grace-expiry SIGKILL, not kernel OOM). 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-kill fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-12 + EDITLOG: **4097 ok / 2047 missing / 0 stale / 0 unknown → `chunks_lost=2047`** — pure S2 tail-loss signature (all missing, zero stale). `flush_failures=0`; `level_fallback_severe=0`.
- Orphans: 1 `.linear.tmp` post-kill (`the_nether/entities/r.0.0` — kill-mid-flush signature per spec 38 §5, recorded not a failure).
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds).
- Sidecars: mirror `samples/12-rc-1/` (EDITLOG, EXPECTED×2, panels incl. autosave-watch + anomalous postsave zeros, stats, mem-series 990, tick-series, verify, tail-stop, runner log `l12-rc1.runner.log`) — driver writes mirror-direct.

## STOP verdict (charter STOP + REPORT — NO FURTHER RUNS)

`❌ STOP — r1 rc: shutdown 120.9s ≥ 120 (SIGKILL after grace, oom=0) + chunks_lost=2047/6144 on a graceful run.` Single ❌ marks the level per verdict rules. STOP+REPORT triggers FIRED (any SIGTERM ❌) — r2/r3/k1/k3 NOT attempted. Baseline FINAL stands (`shutdown 84.3s WARN peak>=85%`, 0 lost ×3). rc stays n=1 provisional-❌ (NOT a level median). Floor held (14≥8); `level_confirmed=12` on every row including r1. `run-queue.json` left `done:["1","3","6","9"]` (12 NOT done — deliberate). State parked: container STOPPED (after 121.0s/137 park stop); shadow jar = rc2 `b0ea2048` (NOT restored to baseline — resume/close-out handles it); tree in `smp-test` volume = post-double-SIGKILL state (any resume MUST pristine-restore first); `stress/level-12/` intact (pristine + small-backup + manifests, 27M); CSV holds the r1 ❌ row (committed as data). AWAITING OWNER DIRECTION: (a) accept L12=❌ and close out, (b) re-run r1 to test fluke, (c) other. Handoff #15: BLOCKED on L12 verdict — L15 MUST NOT start from the L12 tree; needs own convert + pristine restore discipline if resumed.

## Run b2 (warm)

baseline run 2 done: boot=10.708 load=352.1 save=-1 shut=84.3 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0

## Run b3 (warm)

baseline run 3 done: boot=10.304 load=354.2 save=-1 shut=85.2 exit=143 lost=0/6144 dirty=56 tick=-1 cgroup_peak=6144.0

## CLOSE-OUT (2026-09-24 ~04:00–04:30Z) — owner-accepted ❌ FINAL, no re-run

- Acceptance: owner accepted `test #12 rc = ❌ FINAL` (r1 stands, no re-run). r1: shutdown **120.9s** → SIGKILL 137 (grace-expiry, `oom_killed=0`) → **2047/6144 chunks lost** (all missing, S2 tail-loss), 2/2 reproducible with park-stop confirm (**121.0s/137/oom 0** on the post-kill tree). Baseline = WARN FINAL (shutdown median **84.3s**, 0 lost 3/3).
- Grading note: **the level is graded complete by verdict, not by row count.** Axis stands at 4 rows (b1+b2+b3+r1, CSV `test=12` n=4); r2/r3/k1/k3 will NOT run — deliberate, not missing data.
- Why no r2/r3/kills: charter STOP+REPORT fired on the first SIGTERM ❌ (exit 137 on a graceful run + chunks_lost on run<90). Options offered were (a) accept L12=❌ and close out, (b) re-run r1 to test fluke; owner chose (a). Kills are moot post-❌ (the durability pair needs a passing axis to prove against).
- Tree: L12 `dimensions/minecraft/{overworld/{region,entities,poi},the_nether/{region,entities},the_end/{region,entities,poi}}` (~14.2G: OW region 13831575993 + nether region 134021727 + end region 193745043 + entities/poi) removed from `smp-test` volume (incl. the 1 `.linear.tmp` orphan — kill-mid-flush signature, gone with the tree); small world restored from `level-12/smp-test-small-backup` → `smp-test/` back to **1072519 B** (+39B vs pre-test 1072480 — session/metadata drift, NOT region data: 18 small `.linear` files, faithful shape, no poi dirs, 0 `.tmp` orphans; per-dim `data/` + `paper-world.yml` were never moved, left in place; world-root `level.dat`/players/session.lock likewise never staged, left in place).
- Configs restored: wholesale copy of the 3 backup files → `compression-level: 12→6` (pre-test 6), `log-flush-batches: true→false`, NMT line removed from `sexidium-node.args` (diff-verified: all 3 files IDENTICAL to backup post-cp).
- Jars: shadow-server `folia.jar` (node `folia.jar` symlink → shadow, untouched) back to baseline `e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (sha verified post-cp; pre-test state; next agent swaps per run).
- Wipe: `stress/level-12/` removed entirely (tree manifests, pristine, EXPECTED host copies, small-backup — mirror holds EXPECTED/commands/sidecars) + `level-12-convert.log`; `smp-test` logs/cache/crash-reports wiped.
- Disk: free **14G → 27G** (28±1G band ✓); floor 8G held throughout (minimum observed 14G). Container left STOPPED (`sexidium-smp-test` Exited 137, park-stop state, never restarted by this agent). Live stack untouched (all live nodes STOPPED by owner; only `stress/*` + `smp-test` volume ever written).
- `run-queue.json`: `done` stays `["1","3","6","9"]`; `accepted_partial:["12"]` added host + mirror (this close-out).

## FINAL verdict (owner-accepted, no re-run)

- **`❌ FAIL FINAL — test #12 rc: shutdown 120.9s (120s grace-expiry SIGKILL, oom 0), chunks_lost=2047/6144 (S2 tail-loss, all missing), 2/2 reproducible (r1 + 121.0s/137 park-stop confirm).`** Baseline WARN FINAL (n=3, shutdown median 84.3s, 0 lost 3/3). The level is graded complete by verdict, not by row count — r2/r3/kills will NOT run.
- Handoff #15: BLOCK lifted — L15 MUST start from a FRESH convert from source-anvil (L12 tree wiped; `smp-test` holds only the small world; pristine-restore discipline applies as usual). Medians anchor `bytes_on_disk=14182988894, vs_anvil 0.5443`; baseline SIGTERM median shutdown 84.3s; kill rows n/a (SIGKILL-only pair never attempted post-STOP); C1–C7 calibrations in level-01.md (reused, NOT re-derived).

## Loop-5 inputs (from L12 r1)

- Save-all FIRST completion in campaign (**121.3s**) + stats-reset anomaly (`flush_before=9 → flush_after=0`; post-save panel 03:15:11 server-rendered ALL folders `files=0`, `dirty 0/512`, `never flushed`, p50/p99 0us; presave 03:11:44 real data + prestop post-redirty normal dirty 55). No second `Done`, no `Stopping`, no OOM in the 3000-line tail window — stats zeroed WITHOUT restart. OPEN QUESTION: what resets Linear stats during a level-12 save-all drain. Completion timed-line real (stale-guard matched); the 9→0 movement is NOT a save-all effect in the §7 sense.
- RC flush `p50/p99 = 0.0/0.0` ANOMALOUS ZEROS (parser faithfully read server-rendered zeros; NOT -1-absent, NOT 1000/1000 — flagged, not silently bucketed). Prestop panel normal (1000/1000, dirty 55).
- 1× `.linear.tmp` orphan post-kill (`the_nether/entities/r.0.0` — kill-mid-flush signature per spec 38 §5, recorded not a failure; removed at close-out with the tree).
- Re-confirms (already logged L1/L6/L9): `swap_jar` cp-after-start ordering bug (r1 swap-boot Done belongs to pre-swap baseline boot; true rc boot is AXIS `boot_s=10.103`); C6b midnight-date-line parse fix holds (C6 future-skipped=0 on all 4 rows).
