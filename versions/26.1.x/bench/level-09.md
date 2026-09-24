# Level 09 — baseline × 3 + rc2 × 3 + 2 SIGKILL rows — IN PROGRESS

- `test=9` `level_confirmed=9` (3-source: config `compression-level: 9` in `paper-world-defaults.yml` + header audit 8383/8383 lvl=9 at offset 17 + 0 `[region-format]` fallback lines; baseline panel has no `lvl` token per paper-0010, rc token pending)
- `jar=baseline` `jar_sha256=e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (60532041 B, host `stress/jars/folia-baseline.jar` + shadow-server identical, verified 2026-09-23)
- `jar=rc2` `jar_sha256=b0ea20484d85e4adce697cb786bf164b6fa4865d9eb122b8c931910e2723e1d6` (60541066 B, host `stress/jars/folia-rc2.jar`, verified 2026-09-23)
- `ldm=0` `flush_threads=1` `compression_workers=0` (axis-1 defaults)
- `bytes_anvil=26056405704` (frozen constant, S2-finalize 2026-09-22; NOT re-derived, source-anvil read-only)
- `convert_s=911` (t0 20:34:01Z→t1 20:49:12Z; per-dim walls 672.7+23.0+87.2=782.9s, threads 4/1/1, empty `level-9/` dir, ≤8 threads)
- `bytes_on_disk=14444960206` (≈13.45 GiB; OW 14107297350 + nether 136693910 + end 200968946 out-bytes; per-folder `du -sb` minus manifests 2270381; ratio vs Anvil 0.5544, 44.56% saved; saved vs #1 18.86%)
- Conversion (`mca2linear -c 9` per-dim via host helper `level9-convert` on bind-mounted build volume, python:3.13-slim + pyzstd): OW 7382 files in=23318872064 out=14107297350 ratio=0.605 wall=672.7s; nether 117 files in=274874368 out=136693910 ratio=0.497 wall=23.0s; end 884 files in=2462646272 out=200968946 ratio=0.082 wall=87.2s; all `EXIT=0`, `DONE-ALL`; 0 `.mcc`; free 27G→14G (floor 14≥8 PASS)
- Verify (decode-back workaround, harness `verify_level` broken by construction): header audit 8383/8383 lvl=9 bad=0 (offset 17, `>QBQbhI` field 4); manifest src_sha cross-check 7382+117+884=8383/8383 mism=0 missing=0 extra=0 (`level-9` convert.manifest `src_sha` == source-anvil decode `dst_sha`, joined on `.mca` rel); forceload-subset (16 pristine files) `linear2mca` + `verify` per-dim 12/2/2 files all `total diffs=0` (temp mini dirs wiped)
- Pristine: 16 files (OW 4×(region+entities+poi)=12 + nether 2 + end 2) + `pristine.sha256` 16 lines; `EXPECTED.json` 6144 keys (edit-workload.py gen --level 9, sha scheme `sha256("dim|cx|cz|mat|level")` verified on sample key) + `commands-y319.txt` 6144 setblocks (4096 OW @319, zero 320) + `commands.txt` copy staged (mirror `level-9/`)
- Staging (move, not copy — same `/dev/sda6`, rename instant): backed up small world + configs to `level-9/smp-test-small-backup`; moved 8 dirs `level-9/tree/{dims}/{region,entities,poi}` → `smp-test/.../dimensions/minecraft/...` (world region counts OW 2502 / nether 64 / end 676); `TREE` left with manifests only; set `compression-level: 6→9`, `log-flush-batches: false→true`; appended NMT to `sexidium-node.args`. Explicit per-dim `mv` commands (single-quoted SSH, no loop vars — L6 staging lesson honored)
- Smoke boot baseline 20:59Z `Done (10.189s)`, 0 fallback lines, config-readback level 9 → `level_confirmed=9`; console loopback `linearstats` → baseline panel (9 folders, plain `dirtyDepth`, C4 as expected); smc.py `bff98d8c` + smc_batch.py `a2b7376b` (persisted L6 layer, shas re-verified); clean SIGTERM stop (143) afterwards, container STOPPED for b1

## Runs (IN PROGRESS — 8/8: axis 6/6 + SIGKILL kill pair 2/2, OOM skipped per C7)

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 (cold-ish) | 10.2 | 355.8 (per-chunk; batched driver 21×300, staged EDITs; 6144/6144 acks EDITLOG-1+2; C6 guard armed) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 75.2 | 143/0 | -1 (mspt-no-response; 100 polls, 0 pairs) | heap 2108/2960, rss 5385/6138, nmt 6493, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| b2 (warm) | 10.6 | 354.4 (per-chunk; batched driver 21×300, staged EDITs; 3339 head-start, +300/batch to 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 79.3 | 143/0 | -1 (mspt-no-response; 95 polls, 0 pairs) | heap 2526/3072, rss 5378/6146, nmt 6535, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| b3 (warm, last baseline) | 10.2 | 354.4 (per-chunk; batched driver 21×300, staged EDITs; 3387 head-start, +300/batch to 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 77.2 | 143/0 | -1 (mspt-no-response; 95 polls, 0 pairs) | heap 1556/3072, rss 5441/6132, nmt 6579, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| r1 (rc, warm, autosave-watch) | 10.2 | 351.9 (per-chunk; batched driver 21×300, staged EDITs; 3167 head-start, +300/batch to 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 150s cap, movement 9→82 background; 03-H2/H3) | 1000/1000 (rc panel; OW+nether region 1000, entities 10–25, end region 50/250) | 37 | 72.4 | 143/0 | -1 (mspt-no-response; 103 polls, 0 pairs) | heap 1304/3072, rss 5348/6137, nmt 6444, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| r2 (rc, warm) | 10.4 | 352.2 (per-chunk; batched driver 21×300, staged EDITs; 3312 head-start, +300/batch to 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 150s cap, movement true background; 03-H2/H3) | 1000/1000 (rc panel) | 35 | 74.4 | 143/0 | -1 (mspt-no-response; 99 polls, 0 pairs) | heap 1266/3006, rss 5392/6145, nmt 6600, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| r3 (rc, warm, last axis) | 10.8 | 351.6 (per-chunk; batched driver 21×300, staged EDITs; 3386 head-start, +300/batch to 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 150s cap, movement true background; 03-H2/H3) | 1000/1000 (rc panel) | 39 | 69.4 | 143/0 | -1 (mspt-no-response; 98 polls, 0 pairs) | heap 1648/2876, rss 5315/6125, nmt 6632, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |

## Run r3 (rc, warm, last axis run) — rc run 3 done 2026-09-23 23:24Z→23:49Z (driver `loop4-P0-mirror/l9wrap.py rc3`; NO jar swap — shadow already rc2 b0ea2048 since r1; loopback console)

- Gates re-verified: free **14 GiB ≥ 8 floor** (abort <8 never triggered, 14→14); lock = standing `sleep 200000` reservation (precedent); jar rc2 `b0ea2048` (shadow + node, 60541066 B, no swap); config `compression-level: 9` + globals; NMT **ON**; pristine 16/16 sha OK (double restore); EXPECTED-9 + `commands-y319.txt`; plugin `21997aad`; `smp1_players=-1` (live still STOPPED by owner); `nbtlib` local.
- Boot: restore → start → `Done` → `boot_s=10.823`; rc panel `lvl 9` all dims + 0 fallback → `level_confirmed=9`.
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=351.6` (batch-1 acks 3386 head-start from r2 log tail, +300/batch to 6144 at batch 11 proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design.
- Settle: 60s (run 3, no autosave-watch — watch is run-1-per-jar only).
- Save-all: `save-all flush` POST → `{"ok":true}`; 150s capped poll, NO completion line; movement true = background age-flush, NOT save-all effect → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced on all rc runs).
- Flush: rc panel (9 folders, all `lvl 9`): prestop dirty **39** vs r1 37 / r2 35 / baseline 54 — **−28% vs baseline**; overall `flush_p50/p99=1000/1000ms`; `flush_failures=0`.
- Shutdown: SIGTERM → exit = **69.4s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 39; 0 `Failed to flush`. Under 96 (no trigger; **fastest shutdown of the level so far**).
- Tick: 98 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as all prior runs).
- Mem: 929 samples ~1Hz: heap steady **1648** / peak **2876** (under Xmx, NOT saturated); rss steady 5315 / peak (HWM) 6125; **nmt committed peak 6632** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-9 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays in `smp-test` volume for kills; floor holds).
- Sidecars: mirror `samples/9-rc-3/` (EDITLOGs, EXPECTED×2, panels, stats, mem-series 929, tick-series, verify, tail-stop, runner log `l9-rc3.runner.log`; no autosave-watch — run 3) — driver writes mirror-direct.

## rc FINAL medians (3/3) + axis verdict baseline-vs-rc

- Baseline FINAL (n=3): `lvl 9, n=3, WARN, shutdown 77.2s, why=peak>=85%` (renderer). Boot warm median 10.4s (b2 10.611 + b3 10.169; b1 cold-ish 10.236 excluded); load warm median 354.4s (b2 354.4 + b3 354.4; b1 355.8 calibration excluded); shutdown median 77.2s (75.2, 79.3, 77.2); dirty median 54 (54,54,54); lost 0+0+0; exits 143×3; flush p50/p99 absent (correct); save n/a ×3; tick -1 ×3; cgroup 6144.0 (100% cap, reclaimed, no OOM).
- rc FINAL (n=3): `lvl 9, n=3, WARN, shutdown 72.4s, why=peak>=85%` (renderer). Boot median 10.4s (10.178, 10.398, 10.823); load median 351.9s (351.9, 352.2, 351.6); shutdown median 72.4s (72.4, 74.4, 69.4); dirty median 37 (37,35,39); lost 0+0+0; exits 143×3; flush p50/p99 1000/1000 ×3; save n/a ×3; tick -1 ×3; cgroup 6144.0 (100% cap, reclaimed, no OOM).
- Full renderer lines:
  - `lvl 9, n=3, WARN, shutdown 77.2s, tick n/a, flush n/a, save n/a, cgroup 6144MiB, size 14444960206B, vs_anvil 0.554, saved_vs_#1 18.86%, why=peak>=85%` (baseline)
  - `lvl 9, n=3, WARN, shutdown 72.4s, tick n/a, flush 1000.0ms, save n/a, cgroup 6144MiB, size 14444960206B, vs_anvil 0.554, saved_vs_#1 18.86%, why=peak>=85%` (rc)
- Axis verdict (baseline-vs-rc): shutdown 77.2→72.4s (**−6%, −4.8s**); dirty 54→37 (**−31%**); load 354.4→351.9 (−0.7%, decode-independent as expected, direction noise); boot 10.4→10.4s (no change); lost 0/6144 all 6 runs; exits 143×6; flush_fail 0×6; OOM 0×6; fallback 0×6. m0017 age-flush direction holds across all 3 rc runs. No ❌ (single ❌ would mark the level — none seen). star=none (needs all-clear level). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=9, no ❌) — axis COMPLETE, CONTINUE to 2 kill rows (SIGKILL T+30 × baseline+rc2, run=91; OOM skipped per C7).

## Run r2 (rc, warm) — rc run 2 done 2026-09-23 22:56Z→23:22Z (driver `loop4-P0-mirror/l9wrap.py rc2`; NO jar swap — shadow already rc2 b0ea2048 since r1; loopback console)

- Gates re-verified: free **14 GiB ≥ 8 floor** (abort <8 never triggered); lock = standing `sleep 200000` reservation (precedent); jar rc2 `b0ea2048` (shadow + node, no swap); config `compression-level: 9` + globals; NMT **ON**; pristine 16/16 sha OK (double restore); EXPECTED-9 + `commands-y319.txt`; plugin `21997aad`; `smp1_players=-1` (live still STOPPED by owner).
- Boot: restore → start → `Done` → `boot_s=10.398`; rc panel `lvl 9` all dims + 0 fallback → `level_confirmed=9`.
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=352.2` (batch-1 acks 3312 head-start from r1 log tail, +300/batch to 6144 at batch 11 proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design.
- Settle: 60s (run 2, no autosave-watch — watch is run-1-per-jar only).
- Save-all: `save-all flush` POST → `{"ok":true}`; 150s capped poll, NO completion line; movement true = background age-flush, NOT save-all effect → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced on rc).
- Flush: rc panel (9 folders, all `lvl 9`): prestop dirty **35** vs r1 37 / baseline 54 — **−35% vs baseline**; overall `flush_p50/p99=1000/1000ms`; `flush_failures=0`.
- Shutdown: SIGTERM → exit = **74.4s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 35; 0 `Failed to flush`. Under 96 (no trigger; **2.8s under the baseline median 77.2s, 2.0s over r1**).
- Tick: 99 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as all prior runs).
- Mem: 935 samples ~1Hz: heap steady **1266** / peak **3006** (under Xmx, NOT saturated); rss steady 5392 / peak (HWM) 6145; **nmt committed peak 6600** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-9 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds).
- Sidecars: mirror `samples/9-rc-2/` (EDITLOGs, EXPECTED×2, panels, stats, mem-series 935, tick-series, verify, tail-stop, runner log `l9-rc2.runner.log`; no autosave-watch — run 2) — driver writes mirror-direct.

## Run k1 (baseline SIGKILL T+30) — evidence 2026-09-24 00:17Z→00:30Z (driver `loop4-P0-mirror/l9wrap.py k_bskill` REDO; MANUAL jar swap rc2→baseline BEFORE the run per L3 lesson — shadow `e609c1d4` verified on disk + fresh baseline boot 9.985s + `confirm_level` TRUE; loopback console)

- FAILED first attempt (no row, no data impact — driver date-line bug, Loop-5 input): k1 launched 23:59Z, workload crossed midnight UTC; `parse_feedbacks` samples `base=today_utc()` per call, so pre-midnight 23:xx feedback lines scanned post-midnight mapped +24h into the future and were C6-skipped — workload stalled at 5844/6144 (300 keys, exactly the pre-midnight tail) past the 600s deadline → `RuntimeError: STOP: workload incomplete`. All 21 BATCH_DONE + Changed lines existed in the log (server healthy — pure parse artifact). Failed runner log preserved at `l9-k1-failed-midnight.runner.log`; unmeasured stop (137, nothing at stake) + pristine restore; driver fixed (C6b rollover tolerance: future-ts in (now+300, now+86400+300] gets −86400d before the skew-skip) and k1 redone clean. Side effect of C6b: the redo's cumulative scans now count the failed attempt's 23:5x–00:1x acks as stale keys (EDITLOG span below) — same tail-lag mechanism as L1/L3/L6 k1, larger window.
- Gates: free **14 GiB ≥ 8 floor** (abort <8 never triggered, 14→14); lock = standing `sleep 200000` reservation (precedent); jar baseline `e609c1d4` (shadow + node symlink, swapped from rc2 before run); config `compression-level: 9` + globals; pristine 16/16 sha OK (double restore: pre-run unmeasured-stop restore + `run_kill` restore); EXPECTED-9 6144 keys + `commands-y319.txt`; plugin `21997aad`; `smp1_players=-1` (live STOPPED by owner); NMT **ON**.
- Boot: restore → start → `Done` → `boot_s=10.234`; baseline plain panel + 0 fallback → `level_confirmed=9` (asserted inside `run_kill`).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact**; staged 6144 EDITs in 21×300 batches → `load_s=354.5` (batch-1 acks 6144/6144 — full failed-attempt-tail coverage via C6b; exact delivery proven by 21/21 BATCH_DONE; C6 future-skipped=0 post-fix).
- Kill: `t0`=last EDIT ack 00:24:12Z → post-load mem-prekill + prestop linearstats consumed the window (`waiting 0s to T+30` — T+30 had already elapsed) → `docker kill -s SIGKILL sexidium-smp-test` at **t0+48.1s** (NOT t0+30 — timing deviation, honest, same as L6 k1) → `shutdown_s=0.9` (instant), `ExitCode=137` clean-kill, `OOMKilled=false` (captured BEFORE restart). Tail: no clean markers (expected for SIGKILL), 0 `Failed to flush`, no fallback SEVERE, no `.linear.tmp` orphans in tail-kill.
- Safety (REAL decode-back verify, step 7): post-kill fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-9 + EDITLOG: **0 ok / 6144 missing / 0 stale / 0 unknown → `chunks_lost=6144`** — pure S2 tail-loss signature (all missing, zero stale = no cross-run contamination in blocks). `flush_failures=0`; `level_fallback_severe=0`.
- EDITLOG staleness audit (honest, sidecars immutable): 6144 keys span 1177s (min ack 00:04:35Z = failed-attempt tail resurrected by C6b, max 00:24:12Z = k1 t0). As-measured `loss_window_s=1225.1` (stale keys) / `newest_lost_age_s=48.1` (= t0+48.1 actual kill time). Fresh-only window ≈403s (≈ load 354.5 + 48.1) over fresh keys, ALL lost. Baseline S1+S2 CONFIRMED on L9: SIGKILL loses everything including edits acked 48s before kill.
- CSV: row 7 `test=9 jar=baseline run=91 ... exit=137 oom=0 chunks 6144/6144 dirty=54`. Sidecars: mirror `samples/9-baseline-kill-SIGKILL30/` 10 files (EDITLOG, EXPECTED×2, boot panel, mem-prekill, tail-kill, verify, wool-ids, runner log `l9-k1.runner.log`) — driver writes mirror-direct. Per-run wipe logs/cache only (tree stays); `df` 14→14, floor holds.
- STOP+REPORT check: none (137/OOM-false expected for SIGKILL; total loss IS the baseline prediction, not a ❌; no floor breach; level_confirmed=9) — CONTINUE to k3 (rc SIGKILL, manual swap baseline→rc2 + STOP/START + confirm first — working around the `swap_jar` ordering bug).

## Run k3 (rc SIGKILL T+30) — evidence 2026-09-24 00:39Z→00:52Z (driver `loop4-P0-mirror/l9wrap.py k_rskill`; MANUAL jar swap baseline→rc2 + STOP/START + confirm BEFORE the run, working around the `swap_jar` ordering bug — shadow `b0ea2048` verified + fresh rc boot 9.987s + `confirm_level` TRUE all-dims-lvl-9; loopback console)

- Gates: free **14 GiB ≥ 8 floor** (abort <8 never triggered, 14→14); lock = standing `sleep 200000` reservation (precedent); jar rc2 `b0ea2048` (shadow + node symlink, 60541066 B); config `compression-level: 9` + globals; NMT **ON**; pristine 16/16 sha OK (double restore); EXPECTED-9 6144 keys + `commands-y319.txt`; plugin `21997aad`; `smp1_players=-1` (live STOPPED by owner).
- Boot: restore → start → `Done` → `boot_s=9.715`; rc panel `lvl 9` all dims + 0 fallback → `level_confirmed=9` (asserted inside `run_kill`).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact**; staged 6144 EDITs in 21×300 batches → `load_s=354.1` (batch-1 acks 6144/6144 — full k1-tail coverage via C6b; exact delivery proven by 21/21 BATCH_DONE; C6 future-skipped=0).
- Kill: `t0`=last EDIT ack 00:46:19Z → post-load steps again consumed the window (`waiting 0s to T+30`) → SIGKILL at **t0+47.4s** (same timing deviation as k1, honest) → `shutdown_s=0.9`, `ExitCode=137`, `OOMKilled=false` (BEFORE restart). Tail: no clean markers (expected), 0 `Failed to flush`, no fallback SEVERE, no `.linear.tmp` orphans.
- Safety (REAL decode-back verify, step 7): 6 region files pre-restart → reboot → `linear2mca` (errors=0) → nbtlib verifier vs EXPECTED-9 + EDITLOG: **2855 ok / 3289 missing / 0 stale / 0 unknown → `chunks_lost=3289`** (pure missing, zero stale). `flush_failures=0`; `level_fallback_severe=0`.
- Age analysis (the m0017 datum): EDITLOG span 00:04:35 (k1-fail tail, 20 stale keys via C6b) →00:46:19 (k3 t0). Saved (2855): median ack 00:42:31, newest 00:44:25. Lost (3289): median 00:44:41, newest 00:46:19 (=t0+47.4 actual kill). Per-minute lost fraction: 00:40 25% / 00:41 27% / 00:42 33% / 00:43 33% / 00:44 71% / 00:45 100% / 00:46 100% — bulk cutoff ~2 min pre-kill (same as L1/L3/L6); max window 2551.4s from the 20 stale k1-fail-tail keys / fresh-only window ≈402s. As-measured `loss_window_s=2551.4` / `newest_lost_age_s=47.4`.
- m0017 assessment: DIRECTION CONFIRMED on L9 — baseline k1 lost 6144/6144 (100%), rc k3 lost 3289/6144 (54%), saved 2855 (46%) via slow per-file age-flush. Cross-level: L1 rc saved 46% / L3 rc saved 43% / L6 rc saved 47% / L9 rc saved 46% — consistent ~2-min bulk cutoff everywhere. The `≤F+skew` bar needs F's true units (open Loop-5 question from L1, NOT a ❌ — kill rows are data; level already WARN).
- CSV: row 8 `test=9 jar=rc run=91 ... exit=137 oom=0 chunks 3289/6144 dirty=55`. Sidecars: mirror `samples/9-rc-kill-SIGKILL30/` 10 files — driver writes mirror-direct. Per-run wipe logs/cache only; `df` 14→14, floor holds. STOP+REPORT check: none — CONTINUE to close-out (OOM rows skipped per C7, SIGKILL pair complete).

## Provisional verdict (rules: scripts/render-stress-table.py header)

`WARN (axis COMPLETE + k1 baseline SIGKILL data)` — axis medians unchanged (baseline `shutdown 77.2s`, rc `shutdown 72.4s`, both `why=peak>=85%`). k1 (run=91, NOT a level grade per spec 38 §3.3): exit 137, lost 6144/6144 all-missing (S1+S2 on L9), newest 48.1s (T+30 window missed by post-load steps — honest deviation). Failed first attempt documented above (driver date-line bug C6b, fixed, Loop-5 input). No ❌ on any SIGTERM row; no floor breach; `level_confirmed=9` every row. STOP+REPORT triggers: none — CONTINUE to k3.

## Run r1 (rc, autosave-watch) — rc run 1 done 2026-09-23 22:28Z→22:55Z (driver `loop4-P0-mirror/l9wrap.py rc1`, FIRST rc run — jar swap baseline→rc2 included; loopback console)

- Swap (rc1 only): host-fetch rc2 `CACHED b0ea20484d85` (jars pre-staged, no :ro write) → `sha256sum -c` `rc.jar: OK` → cp to shadow + node jars → swap-boot 10.907s (ATTRIBUTION: `swap_jar` cps AFTER start, so this Done belongs to the pre-swap baseline boot — same ordering bug as L6 r1/k1; the true rc boot is the AXIS `boot_s=10.178`). Live stack untouched (live stays STOPPED by owner).
- Gates re-verified: free **14 GiB ≥ 8 floor** (abort <8 never triggered, 14→14); lock = standing `sleep 200000` reservation (precedent: no second lock, no break); config `compression-level: 9` + globals threads 1/workers 0/LDM 0/freq 10/log-batches true; pristine 16/16 sha OK (double restore); EXPECTED-9 6144 keys + `commands-y319.txt`; patched plugin `21997aad`; NMT **ON**; `nbtlib` local.
- Boot: restore → start → `Done` → `boot_s=10.178`; rc panel `lvl 9` on all 3 dims + 0 `[region-format]` fallback → `level_confirmed=9` (spec 32 §4 rc source).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=351.9` (batch-1 acks 3167 head-start from b3 log tail, +300/batch to 6144 at batch 11 proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design.
- Age-wait (autosave-watch, run-1 per jar): 15s (rc age gate) + 65s, flush 9→9 + dirty 55→55 → `autosave_reaches_flush=false`. Periodic age-flush (m0017) did NOT move counters in this settle window — the dirty drop below comes later (save window + shutdown drain).
- Save-all: `save-all flush` POST → `{"ok":true}`; 150s capped poll, NO completion line; pre dirty 55 + flush 9, post flush 82 (movement true = background age-flush, NOT save-all effect) → `save_all_s=n/a (never-invoked)` per spec 33 §7 (cite 03-H2, 03-H3; C3 reproduced on rc — save-all still no completion line even with m0017/counters).
- Flush: rc panel (9 folders, all `lvl 9`): prestop dirty **37** vs baseline median 54 — **−31%**; overall `flush_p50/p99=1000/1000ms` (OW + nether region 1000/1000; entities 10–25, end region 50/250); `flush_failures=0`.
- Shutdown: SIGTERM → exit = **72.4s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 37; 0 `Failed to flush`. Under 96 (no trigger; **4.8s under the baseline median 77.2s**).
- Tick: 103 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as all prior runs).
- Mem: 988 samples ~1Hz: heap steady **1304** / peak **3072** (= Xmx, saturated, no ExitOnOOM — exit 143 proves it); rss steady 5348 / peak (HWM) 6137; **nmt committed peak 6444** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-9 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays in `smp-test` volume for r2/r3; floor holds).
- Sidecars: mirror `samples/9-rc-1/` (EDITLOGs, EXPECTED×2, panels incl. autosave-watch, stats, mem-series 988, tick-series, verify, tail-stop, runner log `l9-rc1.runner.log`) — driver writes mirror-direct.

## Provisional verdict (rules: scripts/render-stress-table.py header)

`WARN (baseline FINAL n=3 unchanged + rc n=1 provisional)` — baseline medians stay `lvl 9, n=3, WARN, shutdown 77.2s, why=peak>=85%`. rc r1 provisional (NOT a level verdict): shutdown 72.4s <96, dirty 37 (−31% vs baseline 54), lost 0, exit 143, 0 failures — direction matches the m0017 age-flush expectation (cut dirty; shutdown delta pending n=3) but n=1 proves nothing yet; need r2+r3 + 2 kills. No ❌ (single ❌ would mark the level — none seen). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=9, no ❌) — CONTINUE to r2.

## Evidence (run b2)

- Boot: restore 21:29Z (16/16 sha OK, double restore: pre-run unmeasured-stop restore + `run_axis` restore) → start → `Done` → `boot_s=10.611`; baseline plain panel + config 9 + 0 fallback → `level_confirmed=9` (patient-linearstats: first try clean, no retry needed)
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=354.4` (batch-1 acks 3339 head-start from b1 log tail, +300/batch to 6144 at batch 11 proves fresh; C6 future-skipped=0 all 21 batches); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design
- Settle: 60s (run 2, no autosave-watch — watch is run-1-per-jar only)
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line; movement=false → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced b1+b2)
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5)
- Shutdown: SIGTERM → exit = **79.3s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 54; 0 `Failed to flush`. Under 96 (no trigger)
- Tick: 95 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as b1)
- Mem: 912 samples ~1Hz: heap steady **2526** / peak **3072** (= Xmx, saturated, no ExitOnOOM — exit 143 proves it); rss steady 5378 / peak (HWM) 6146; **nmt committed peak 6535** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only)
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-9 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds)
- Sidecars: mirror `samples/9-baseline-2/` (EDITLOGs, EXPECTED×2, panels, stats, mem-series 912, tick-series, verify, tail-stop, runner log `l9-b2.runner.log`) — driver writes mirror-direct

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS (baseline n=2 provisional — NOT a level verdict)` — shutdown median 77.3s (75.2, 79.3) <96 (no trigger); cgroup 6144.0 = 100% cap → WARN-side `peak>=85%` datum (same as L1/L3/L6). Load 355.8→354.4 (b1 cold-ish excluded from warm medians per §5; single warm datum 354.4s so far). No ❌ (both exits 143, 0 lost, 0 failures, 0 OOM, fallback 0). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=9, no ❌) — CONTINUE to b3.

## Run b3 (warm, last baseline) — baseline run 3 done 2026-09-23 21:56Z→22:20Z (driver `loop4-P0-mirror/l9wrap.py b3`; loopback console, NO jar swap — shadow already baseline e609c1d4)

- Gates re-verified: free **14 GiB ≥ 8 floor** (abort <8 never triggered); lock = standing `sleep 200000` reservation (precedent: no second lock, no break); jar baseline `e609c1d4` (shadow + node, 60532041 B); config `compression-level: 9` + globals threads 1/workers 0/LDM 0/freq 10/log-batches true; NMT **ON**; pristine 16/16 sha OK (double restore); EXPECTED-9 6144 keys + `commands-y319.txt`; patched plugin `21997aad`; `smp1_players=-1` (live STOPPED by owner, no live-log lines — honest unknown); `nbtlib` local.
- Boot: restore → start → `Done` → `boot_s=10.169`; baseline plain panel + config 9 + 0 fallback → `level_confirmed=9` (patient-linearstats: first try clean, no retry needed).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=354.4` (batch-1 acks 3387 head-start from b2 log tail, +300/batch to 6144 at batch 11 proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design.
- Settle: 60s (run 3, no autosave-watch — watch is run-1-per-jar only).
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line; movement=false → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced b1+b2+b3).
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5).
- Shutdown: SIGTERM → exit = **77.2s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 54; 0 `Failed to flush`. Under 96 (no trigger).
- Tick: 95 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as b1/b2).
- Mem: 903 samples ~1Hz: heap steady **1556** / peak **3072** (= Xmx, saturated, no ExitOnOOM — exit 143 proves it); rss steady 5441 / peak (HWM) 6132; **nmt committed peak 6579** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-9 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds).
- Sidecars: mirror `samples/9-baseline-3/` (EDITLOGs, EXPECTED×2, panels, stats, mem-series 903, tick-series, verify, tail-stop, runner log `l9-b3.runner.log`) — driver writes mirror-direct.

## Baseline FINAL medians (3/3) + provisional verdict

- Baseline FINAL (n=3): `lvl 9, n=3, WARN, shutdown 77.2s, why=peak>=85%` (renderer). Boot warm median 10.4s (b2 10.611 + b3 10.169; b1 cold-ish 10.236 excluded); load warm median 354.4s (b2 354.4 + b3 354.4; b1 355.8 calibration excluded); shutdown median 77.2s (75.2, 79.3, 77.2); dirty median 54 (54,54,54); lost 0+0+0; exits 143×3; flush p50/p99 absent (correct); save n/a ×3; tick -1 ×3; cgroup 6144.0 (100% cap, reclaimed, no OOM).
- vs L1/L3/L6 baselines: shutdown 77.2s vs 80.0 (L1) / 80.3 (L3) / 74.4 (L6) — between L3 and L6; dirty 54 same as L6; load 354.4 identical (decode-independent as expected); lost 0/6144 all runs.
- `WARN (baseline FINAL n=3 — axis half COMPLETE)` — no shutdown trigger (77.2 <96); no ❌. Level verdict PENDING (need 3 rc + 2 kills). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=9, no ❌) — CONTINUE to r1 (first rc: swap shadow→rc2 b0ea2048 via `swap_jar` on rc1 ONLY).

## Evidence (run b1)

- Boot: restore (16/16 sha OK) → start → `Done` → `boot_s=10.236`; baseline plain panel (9 folders, `dirtyDepth`, no lvl/p50/p99 — C4) + config-readback 9 + 0 `[region-format]` fallback → `level_confirmed=9`; jar baseline `e609c1d4` (shadow + symlink); `smp1_players=-1` (live STOPPED by owner, no live-log lines — honest unknown); `started_at=2026-09-23T21:01:24Z`
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (asserted in-driver); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=355.8` (EDITLOG-1 6144 keys; exact batch delivery proven by 21/21 BATCH_DONE asserted in-driver + 0-lost verify below); pass 2 redirty identical setblocks → EDITLOG-2 6144 keys, pass-2 timing DISCARDED by design; `load_evidence=per-chunk`; `tail-stop.txt` shows `Could not set the block` spam ×1456 under high cgroup (same pattern as L1 b3/L6 b2) but delivery proven by BATCH_DONE + verify
- Age-wait (autosave-watch, run-1 baseline): 15s + 65s, flush 0→0 + dirty 54→54 → `autosave_reaches_flush=false` (S1 reproduced on L9: steady-state no-flush on baseline)
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line → `save_all_s=n/a (never-invoked)` per spec 33 §7 (cite 03-H2, 03-H3, 02-Unknowns); movement=false (C3 reproduced on L9)
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5)
- Shutdown: SIGTERM → exit = **75.2s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (`Stopping server`, `Saved all worlds`, `All RegionFile I/O tasks`); dirty_at_stop 54; 0 `Failed to flush`. Under 96 (no trigger)
- Tick: 100 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as L1/L3/L6)
- Mem: 946 samples ~1Hz: heap steady **2108** / peak **2960** (under Xmx 3072 — NOT saturated); rss steady 5385 / peak (HWM) 6138; **nmt committed peak 6493** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only, same precedent)
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs staged EXPECTED-9 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`** (`verify.json` in mirror). `flush_failures=0`; `level_fallback_severe=0`
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds)
- Sidecars: mirror `samples/9-baseline-1/` 26 files (EDITLOGs, EXPECTED×2, panels incl. autosave-watch, stats, mem-series 946, tick-series, verify, tail-stop) — driver writes mirror-direct, no separate sync needed

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS (b1 only, n=1 — NOT a level verdict)` — shutdown 75.2s <96 (no trigger); cgroup 6144.0 = 100% cap → WARN-side `peak>=85%` datum when renderer runs (same as L1/L3/L6). No ❌ (exit 143, 0 lost, 0 failures, 0 OOM, fallback 0). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=9, no ❌) — CONTINUE to b2.

## Run b1 (cold-ish)

baseline run 1 done: boot=10.236 load=355.8 save=-1 shut=75.2 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0

## Run b2 (warm)

baseline run 2 done: boot=10.611 load=354.4 save=-1 shut=79.3 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0

## Run b3 (warm)

baseline run 3 done: boot=10.169 load=354.4 save=-1 shut=77.2 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0

## Run r1 (rc, autosave-watch)

rc run 1 done: boot=10.178 load=351.9 save=-1 shut=72.4 exit=143 lost=0/6144 dirty=37 tick=-1 cgroup_peak=6144.0

## Run r2 (rc)

rc run 2 done: boot=10.398 load=352.2 save=-1 shut=74.4 exit=143 lost=0/6144 dirty=35 tick=-1 cgroup_peak=6144.0

## Run r3 (rc)

rc run 3 done: boot=10.823 load=351.6 save=-1 shut=69.4 exit=143 lost=0/6144 dirty=39 tick=-1 cgroup_peak=6144.0

## Run k1 baseline SIGKILL T+30

kill baseline SIGKILL30: lost=6144 window=1225.0646963119507: boot=10.234 load=354.5 save=-1 shut=0.9 exit=137 lost=6144/6144 dirty=54 tick=-1 cgroup_peak=5813.2

## Run k3 rc SIGKILL T+30

kill rc SIGKILL30: lost=3289 window=2551.4499917030334: boot=9.715 load=354.1 save=-1 shut=0.9 exit=137 lost=3289/6144 dirty=55 tick=-1 cgroup_peak=6099.2

## CLOSE-OUT (2026-09-24 ~01:00–01:15Z)

- Final stop: SIGTERM 120s grace → post-kill-verify idle server exited clean `ExitCode=143` unmeasured (no row; no data at stake). Container left STOPPED, volumes intact.
- Tree: L9 `dimensions/minecraft/{overworld/{region,entities,poi},the_nether/{region,entities},the_end/{region,entities,poi}}` (~13.5G) removed from `smp-test` volume (0 `.linear.tmp` orphans anywhere at close-out); small world restored from `level-9/smp-test-small-backup` → `smp-test/` back to **1072499 B** (+19B vs pre-test 1072480 — session/metadata drift, NOT region data: 18 small `.linear` files, faithful shape, no poi dirs; per-dim `data/` + `paper-world.yml` were never moved, left in place; world-root `level.dat`/players/session.lock likewise never staged, left in place).
- Configs restored: wholesale copy of the 3 backup files → `compression-level: 9→6` (pre-test 6), `log-flush-batches: true→false`, NMT line removed from `sexidium-node.args` (verified: level 6, batches false, NMT absent).
- Jars: shadow-server `folia.jar` (node `folia.jar` symlink → shadow) back to baseline `e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (sha verified post-cp; pre-test state; next agent swaps per run).
- Wipe: `stress/level-9/` removed entirely (tree manifests, pristine, EXPECTED host copies, small-backup — mirror holds EXPECTED/commands/sidecars) + `level-9-convert.log` + `level-9-verify.log`; `smp-test` logs/cache/crash-reports wiped.
- Disk: free **14G → 27G** (pre-test 27G exact ✓; 28±1G band ✓); floor 8G held throughout (minimum observed 14G). One-run rule held (reservation lock untouched by others). Live stack untouched as left by owner (all live nodes STOPPED — owner-muted; only `stress/*` + `smp-test` volume ever written by this agent).

## FINAL verdict (rules: scripts/render-stress-table.py — renderer exists, quoted by construction)

- Renderer (provisional rules; agent 41 finalizes; kill rows run=91 INCLUDED in n):
  - `jar=baseline: lvl 9, n=4, X, shutdown ~77.2s, tick n/a, flush n/a, save n/a, cgroup 6144MiB, size 14444960206B, vs_anvil 0.554, saved_vs_#1 18.86%, why=unsafe` — `star=none yet. X above 1: chunks lost on restart.`
  - `jar=rc: lvl 9, n=4, X, shutdown ~72.9s, tick n/a, flush 1000.0ms, save n/a, cgroup 6144MiB, size 14444960206B, vs_anvil 0.554, saved_vs_#1 18.86%, why=unsafe` — same star/X note.
- Interpretation: the X is MECHANICAL (kill-loss data counted by design — spec 38 §3.3: kills inform the fix proof, they do not grade levels safe). Axis (SIGTERM) reference stays: baseline FINAL `shutdown 77.2s WARN peak>=85%`, rc FINAL `shutdown 72.4s WARN peak>=85%`, 0 lost all 6 rows. The kill pair is the durability proof, not a grade change.
- **`⚠️ WARN FINAL — level 9 axis COMPLETE (6/6) + SIGKILL kill pair COMPLETE (2/2), OOM pair SKIPPED (uninducible, C7 carried from L1, NOT re-attempted on L9).`** No ❌ on any SIGTERM row; no floor breach; `level_confirmed=9` every row. m0017 proof on L9: baseline SIGKILL loses 6144/6144 incl. 48s-fresh edits (S1+S2) → rc SIGKILL saves 2855/6144 (46%) with ~2-min bulk cutoff (direction confirmed; `≤F+skew` bar needs F units from agent-21, open Loop-5 question from L1). OOM rollback path untested (no kill inducible 2G→128M per L1 C7). `run-queue.json done:["1","3","6","9"]` set host + mirror (this close-out). Handoff #12: medians anchor `size 14444960206B, vs_anvil 0.554, saved_vs_#1 18.86%`; baseline SIGTERM median shutdown 77.2s / rc 72.4s; kill rows run=91 (SIGKILL T+30 nominal, actual t0+48.1/47.4 honest deviation, test=9); C1–C7 calibrations in level-01.md (reused, NOT re-derived); L9 tooling notes: host-helper conversion (live worker nodes stay down — `level9-convert` on bind-mounted build volume, python:3.13-slim + pyzstd), loopback console via smp-test (`l9wrap.py`, mirror-local), patient-linearstats settle+retry, host-df fallback, `swap_jar` cp-after-start ordering bug (manual swap+confirm before kills AND before rc1-attribution note), C6b midnight-date-line parse fix in `l9run.py` (port to the shared driver — Loop-5 input), failed k1 attempt log `l9-k1-failed-midnight.runner.log` (no row), small-world +19B drift note.
