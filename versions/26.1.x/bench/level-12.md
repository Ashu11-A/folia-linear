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

## Runs (IN PROGRESS — 1/8: axis 1/6 + SIGKILL kill pair 0/2, OOM skipped per C7)

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 (cold-ish) | 10.1 | 352.5 (per-chunk; batched driver 21×300, staged EDITs; 6144/6144 acks EDITLOG-1+2; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 82.2 | 143/0 | -1 (mspt-no-response; 100 polls, 0 pairs) | heap 1248/2896, rss 5325/6139, nmt 6467, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |

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
