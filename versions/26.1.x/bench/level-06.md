# Level 06 — baseline × 3 + rc2 × 3 + 2 SIGKILL rows — IN PROGRESS (PROPOSED DEFAULT)

> Level 6 is the proposed default (agent 44 blocked unless #6 is not ❌; ⚠️/🟡
> replans Loop 5). Extra gate care applies: STOP + REPORT on any SIGTERM ❌,
> floor breach, or level_confirmed≠6. Do not continue past a failure.

- `test=6` `level_confirmed=6` (3-source: config `compression-level: 6` in `paper-world-defaults.yml` + header audit 8383/8383 lvl=6 at offset 17 + 0 `[region-format]` fallback lines; baseline panel has no `lvl` token per paper-0010, rc token pending)
- `jar=baseline` `jar_sha256=e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (60532041 B, host `stress/jars/folia-baseline.jar` + shadow-server identical, verified 2026-09-23)
- `jar=rc2` `jar_sha256=b0ea20484d85e4adce697cb786bf164b6fa4865d9eb122b8c931910e2723e1d6` (60541066 B, host `stress/jars/folia-rc2.jar`, verified 2026-09-23)
- `ldm=0` `flush_threads=1` `compression_workers=0` (axis-1 defaults)
- `bytes_anvil=26056405704` (frozen constant, S2-finalize 2026-09-22; NOT re-derived, source-anvil read-only)
- `convert_s=698` (t0 13:09:27Z→t1 13:21:05Z; per-dim walls 593.8+16.5+76.9=687.2s, threads 4/1/1, empty `level-6/` dir, ≤8 threads)
- `bytes_on_disk=14887028404` (≈13.86 GiB; OW 14535217398 + nether 141380364 + end 210430642; per-folder `du -sb`, manifests excluded; ratio vs Anvil 0.5713, 42.87% saved; saved vs #1 16.37%)
- Conversion (`mca2linear -c 6` per-dim via `worker-2` python3): OW 7382 files in=23318872064 out=14535217398 ratio=0.623 wall=593.8s; nether 117 files in=274874368 out=141380364 ratio=0.514 wall=16.5s; end 884 files in=2462646272 out=210430642 ratio=0.085 wall=76.9s; all `EXIT=0`, `DONE-ALL`; 0 `.mcc`; free 28G→14G (floor 14≥8 PASS)
- Verify (decode-back workaround, harness `verify_level` broken by construction): header audit 8383/8383 lvl=6 bad=0 (offset 17, `>QBQbhI` field 4); manifest src_sha cross-check 7382+117+884=8383/8383 mism=0 missing=0 (`level-6` convert.manifest `src_sha` == recomputed source-anvil sha256, joined on `.mca` rel); forceload-subset (16 files) `linear2mca` + `verify` per-dim 12/2/2 files all `total diffs=0` (first attempt compared the wrong dir pair — `only-src` artifact, NOT data; redone linear→decoded vs src-mca, all zero; temp mini dirs wiped)
- Pristine: 16 files (OW 4×(region+entities+poi)=12 + nether 2 + end 2) 25267422 B + `pristine.sha256` 16 lines; `EXPECTED.json` 6144 keys (edit-workload.py gen --level 6, sha scheme verified) + `commands-y319.txt` 6144 setblocks + `commands.txt` copy staged (mirror `level-6/`)
- Staging (move, not copy — same `/dev/sda6`, rename instant, free 14G): backed up small world + configs to `level-6/smp-test-small-backup`; moved 8 dirs `level-6/tree/{dims}/{region,entities,poi}` → `smp-test/.../dimensions/minecraft/...` (world region counts OW 2502 / nether 64 / end 676); `TREE` left with manifests only; `compression-level` already 6 (pre-test state, verified), `log-flush-batches: false→true`; appended NMT to `sexidium-node.args`
- STAGING INCIDENT (this agent, quarantined, no data impact): the staging loop ran with locally-expanded empty vars (double-quoted SSH command) — first `mv` relocated the whole `minecraft/` dir into the backup, second `mv` renamed `tree/` to `minecraft/`. Net region-data effect identical to plan (small region dirs in backup, L6 tree in world, no file mixing — `mv` renames are atomic on one fs), but `convert.manifest` files landed inside the world dims and small-world `data/`+`paper-world.yml` sat in the backup. Repaired explicitly per-dim: manifests back to `level-6/tree/<dim>/`, `data/`+`paper-world.yml` back to each world dim. Verified post-repair: world dims hold L6 region/entities/poi + data + paper-world.yml, counts 2502/64/676; backup holds small region/entities + 3 configs. Pristine (snapshotted pre-move from tree content) unaffected — each run's restore re-verifies 16/16 sha. Lesson for remaining agents: single-quote SSH remote commands (or explicit per-dim commands), never loop vars under double quotes.
- Smoke boot baseline 13:26:02Z `Done (9.681s)`, 0 fallback lines, config-readback level 6 → `level_confirmed=6`; console live-fire `linearstats` → `{"ok":true}` + baseline panel (9 folders, plain `dirtyDepth`, C4 as expected); clean SIGTERM stop (143) afterwards, container STOPPED for b1

## Runs (IN PROGRESS — 6/8: axis COMPLETE (baseline FINAL + rc FINAL), 2 kills pending)

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 (cold-ish) | 9.7 | 377.4 (per-chunk; 6144/6144 Changed; C1+C2 recipes; L3-log-tail head-start caveat) | n/a (never-invoked; 90s cap, 0 completion; 03-H2/H3) | -/- (baseline absent, correct) | 55 | 74.4 | 143/0 | -1 (mspt-no-response; 93 polls, 0 pairs) | heap 1386/2850, rss 5324/6140, nmt 6539, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| b2 (warm) | 10.5 | 355.0 (per-chunk; batched driver 21×300, staged EDITs; 4892 head-start, +300/batch to 6144 at batch 6) | n/a (never-invoked; 90s cap, 0 movement; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 77.4 | 143/0 | -1 (mspt-no-response; 95 polls, 0 pairs) | heap 2284/2990, rss 5451/6139, nmt 6515, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 13→13 (no breach) |
| b3 (warm, last baseline) | 11.0 | 354.7 (per-chunk; batched driver 21×300, staged EDITs; 3350 head-start, +300/batch to 6144 at batch 10) | n/a (never-invoked; 90s cap, 0 movement; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 74.3 | 143/0 | -1 (mspt-no-response; 95 polls, 0 pairs) | heap 1254/2948, rss 5409/6144, nmt 6539, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 13→10 (neighbor ate 3G, no breach) |
| r1 (rc, warm, autosave-watch) | 10.2 | 354.4 (per-chunk; batched driver 21×300, staged EDITs; 3179 head-start, +300/batch to 6144 at batch 11) | n/a (never-invoked; 150s cap, movement 9→79 background; 03-H2/H3) | 1000/1000 (rc panel; OW+nether region 1000, entities 10–25, end region 50/250) | 40 | 74.3 | 143/0 | -1 (mspt-no-response; 104 polls, 0 pairs) | heap 1788/3028, rss 5391/6123, nmt 6332, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 10→10 (no breach) |
| r2 (rc, warm) | 9.9 | 354.6 (per-chunk; batched driver 21×300, staged EDITs; 3285 head-start, +300/batch to 6144 at batch 11) | n/a (never-invoked; 150s cap, movement 9→77 background; 03-H2/H3) | 1000/1000 (rc panel) | 41 | 71.3 | 143/0 | -1 (mspt-no-response; 99 polls, 0 pairs) | heap 1374/3072, rss 5400/6116, nmt 6402, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 10→14 (neighbor cleaned core, no breach) |
| r3 (rc, warm, last axis) | 10.2 | 355.0 (per-chunk; batched driver 21×300, staged EDITs; 3342 head-start, +300/batch to 6144 at batch 11) | n/a (never-invoked; 150s cap, movement 9→79 background; 03-H2/H3) | 1000/1000 (rc panel) | 40 | 72.3 | 143/0 | -1 (mspt-no-response; 99 polls, 0 pairs) | heap 2524/3072, rss 5379/6134, nmt 6699, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |

CSVs: 3 rows appended (test=6 baseline runs 1–3); sidecars in mirror `samples/6-baseline-1/` (26 files, mem-series 806) + `samples/6-baseline-2/` (25 files, mem-series 883) + `samples/6-baseline-3/` (25 files: panels, stats, EDITLOGs, EXPECTED, mem-series 872, tick-series, verify, tail-stop) BEFORE wipe; orphaned 16:02Z confirm-fail sidecars preserved aside at `samples/6-baseline-2-failed-confirm1605Z/` + 13:56Z invalid-shutdown log at `samples/6-baseline-2-invalid-shutdown/` (NOT part of any row). Per-run wipe done (logs/cache only, tree stays in `smp-test` volume); `free_after_wipe_gib` 13 (b2) / 10 (b3 — prominence-2 neighbor dumped a 2.6G core + 400M mrpack mid-run, NOT test footprint) via driver `clean_run`.

Medians (renderer-computed; warm medians for boot/load per agent 32 §6):
`baseline FINAL (b1+b2+b3): shutdown median 74.4s (<96, no trigger); trigger peak>=85% (cgroup 6144.0 MiB = 100% of 6GiB). star=none yet. No unsafe level yet. Full renderer line: lvl 6, n=3, WARN, shutdown 74.4s, tick n/a, flush n/a, save n/a, cgroup 6144MiB, size 14887028404B, vs_anvil 0.571, saved_vs_#1 16.37%, why=peak>=85%. Spread: shutdown 74.3–77.4 (4% of median, shows median only); boot warm median 10.7s (b2 10.453 + b3 10.981; b1 cold-ish 9.749 excluded per §5); load warm median 354.9s (b2 355.0 + b3 354.7; b1 377.4 calibration excluded); dirty median 54 (55,54,54).`

## Evidence (run b1)

- Boot: restore 13:27:09Z (16/16 sha OK — post-repair validation) → start → `Done (9.749s)`; 0 `[region-format]` lines (healthy, no fallback); config-readback level 6 + headers 8383 lvl=6 → `level_confirmed=6`; jar baseline `e609c1d4` (shadow + symlink); `smp1_players=0` (live-log read, no live command); `started_at=2026-09-23T13:27:09Z`
- Load: forceload 24-add C1 recipe → query **4096/1024/1024 exact**; pass 1 staged 6144 EDITs in 21×300 batches → `load_s=377.4` (batch-1 scan already 6144/6144 — full head-start from the L3 json-log tail: docker json-file logs persist across the volume-log wipe, same mechanism as L1 b2/b3; exact batch delivery proven by 21/21 BATCH_DONE + 6144-ok verify below); pass 2 redirty identical setblocks → all 21 BATCH_DONE, `load_s=-259.4` DISCARDED by design; `load_evidence=per-chunk`
- Age-wait (autosave-watch, run-1 baseline): 15s + 65s, flush 0→0 + dirty 54→54 → `autosave_reaches_flush=false` (S1 reproduced on L6: steady-state no-flush on baseline)
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line → `save_all_s=n/a (never-invoked)` per spec 33 §7 (cite 03-H2, 03-H3, 02-Unknowns); C3 reproduced on L6 (post-save dirty 54→55 drift = background writes, NOT save-all effect)
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5)
- Shutdown: SIGTERM → exit = **74.4s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt`; dirty_at_stop 55; 0 `Failed to flush`. Under 96 (no trigger; **5.6–5.9s under the L1/L3 baseline medians 80.0/80.3s**)
- Tick: 93 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as L1/L3; sidecars `mspt.txt` + `tick-series-*.json` 0 pairs + `tick-cooked.json`)
- Mem: 806 samples ~1Hz: heap steady **1386** / peak **2850** (under Xmx 3072 — NOT saturated, unlike L1/L3); rss steady 5324 / peak (HWM) 6140; **nmt committed peak 6539** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill (95% guard flagged throughout, flag only — same as L1/L3 precedent)
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs staged EXPECTED-6 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`** (`verify.json` in mirror). `flush_failures=0`; `level_fallback_severe=0`
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; df assert 14→14, floor holds)

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS (b1 only, n=1 — NOT a level verdict)` — shutdown 74.4s <96 (no trigger); cgroup 6144.0 = 100% cap → WARN-side `peak>=85%` datum when renderer runs (same as L1/L3). No ❌ (exit 143, 0 lost, 0 failures, 0 OOM, fallback 0). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=6, no ❌) — CONTINUE to b2.

## Evidence

- Pre-run gates verified 2026-09-23 (all read-only unless noted):
  - Host free: **28 GiB** (`df -B1G`, `/dev/sda6` 89G, 61G used) ≥ 22 GiB pre-test need, ≥ 8 GiB floor → PASS. Abort <8G armed.
  - Lock: standing `sleep 200000` reservation (PID 3159562, since 11:25Z Sep-22) holds `stress/harness.lock` (`fuser` confirms); no active driver, no converter contention → one-run rule satisfied under L1/L3 precedent (no second lock, no break).
  - `smp-test` container STOPPED (L3 close-out state); small world **1046710 B** ✓; shadow jar baseline e609c1d4 ✓; `folia.jar` symlink → shadow ✓.
  - Config pre-test state: `compression-level: 6` (L3 close-out restored) + globals threads 1/workers 0/LDM 0/freq 10/`log-flush-batches: false`; NMT absent (re-add at staging, revert at close-out).
  - Patched plugin `sexidium-paper-26.1.2+16.jar` 21997aad ✓.
  - Console path via worker-2 (worker-1/proxy/lobby still exited since 2026-09-23 07:38Z — live, read-only, not restarted): `worker-2:/tmp/smc.py` sha `bff98d8c…` ✓, `smc_batch.py` `a2b7376b` ✓; `smp1_players` via live-log read only.
  - source-anvil intact (overworld/the_nether/the_end + convert.manifests); converter `/srv/build/repo/scripts/vendor/mca2linear-convert.py` present; `convert.lock/` empty.
  - Workload artifacts generated offline (local): `level-6/EXPECTED.json` 6144 keys (edit-workload.py gen --level 6, y=319 OW per C2, sha `3e169993…`) + `commands-y319.txt` 6144 setblocks + `commands.txt` copy; sha scheme `sha256("dim|cx|cz|mat|level")` level=6 verified on sample key; chunk set identical to L3 (same 6144 chunks, wool rotation differs by level).
  - Driver `loop4-P0-mirror/l6run.py` (from `l3run.py`: LEVEL=6, staged L6 EXPECTED, k_boom/k_room disabled per C7 charter, tags `6-*`); py_compile OK; loads EXP 6144 / CMDS 6144 / FORCELOADS 24.
  - `run-queue.json` host + mirror `done:["1","3"]`, stage `P0-level-3-done` (L6 updates at close-out only).
- Calibrations reused from L1 (level-01.md, NOT re-derived): C1 forceload 24-add block-coord recipe; C2 OW y=319 (already in edit-workload.py DIM_Y + staged commands); C3 save-all no-op → capped poll + §7 movement rule; C4 baseline panel no lvl/p50/p99 (config+headers confirm); C5 header level byte at offset 17 (`>QBQbhI` field 4); C6 exclude future-dated acks (parse_feedbacks guard + tick sampler); C7 scoped-cgroup OOM uninducible — NO OOM attempts on L6 (SIGKILL-only kills).
- Driver gap (carried from L3): `l6run.py` k_bskill/k_rskill perform NO jar swap — swap manually via `P.swap_jar` (or `p0run.py swap`) BEFORE kill runs and confirm_level; F-units open question (m0017 `≤F+skew` bar needs F's true units from agent-21).

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS — no rows` — conversion pending. STOP+REPORT triggers armed: floor breach (<8G), level_confirmed≠6, any SIGTERM ❌ (blocks default-flip — report, don't continue).

## Blockers / anomalies

- None. OOM rows excluded by charter (C7). EDIT-600 eviction NOT in charter L6 (skip — base 6144 only).

## Run b1 (cold-ish)

baseline run 1 done: boot=9.749 load=377.4 save=-1 shut=74.4 exit=143 lost=0/6144 dirty=55 tick=-1 cgroup_peak=6144.0

## Run b2 (warm) — baseline run 2 done 2026-09-23 16:32:03Z→16:56:47Z (driver `loop4-P0-mirror/l6wrap.py b2`; REDO of the 13:56Z invalid attempt + the 16:02Z confirm-fail, whose partial sidecars sit aside at `samples/6-baseline-2-invalid-shutdown/` + `samples/6-baseline-2-failed-confirm1605Z/` and contribute no row)

- Env (new, Loop-5 inputs): host `docker ps` is BLIND (sexidium runs in DinD `2deae00e`, host dockerd lost it ~Sep-20) — control plane is Portainer FRP :26152. Owner stopped live nodes ~16:07Z to free RAM (restarts approved); worker-2 restart hangs reproducibly at pool-warm (live-side issue, reported; left STOPPED). Console ran LOOPBACK from smp-test itself (python3 apt-installed in container layer, smc.py/smc_batch.py staged in /tmp, shas bff98d8c/a2b7376b == sources; wrapper `l6wrap.py`, no repo edits). smp-1 STOPPED by owner → `smp1_players=-1` (no live-log lines; honest unknown, not 0).
- Gates re-verified: free **13 GiB ≥ 8 floor** (df_floor 13 at 16:30:54Z, abort <8 never triggered, 13→13); lock = standing `sleep 200000` reservation (PID 3159562, no active driver — b1/L1/L3 precedent: no second lock, no break); jar baseline `e609c1d4` (shadow + node, no swap); config `compression-level: 6` + globals threads 1/workers 0/LDM 0/freq 10/log-batches true; NMT **ON**; pristine 16/16 sha OK (double restore: pre-run unmeasured-stop restore + `run_axis` restore); EXPECTED-6 6144 keys + `commands-y319.txt` 6144 lines (mirror-staged); patched plugin `21997aad`; `nbtlib` local.
- Boot: restore 16:32:05Z → start → `Done` → `boot_s=10.453`; baseline plain panel (9 folders, `dirtyDepth`, no lvl/p50/p99 — C4) + config-readback 6 + 0 `[region-format]` fallback → `level_confirmed=6`. Patient-linearstats wrapper (20s settle + retry) absorbed the 16:02Z confirm race (fresh-boot echo/panel missed the 5s log window → unparsed; Loop-5 driver input).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=355.0` (batch-1 acks 4892 head-start from prior-boot log tail, +300/batch to 6144 at batch 6 proves fresh; C6 future-skipped=0 all batches); pass 2 redirty identical setblocks → all 21 BATCH_DONE, `load_s=-283.8` DISCARDED by design; `tail-stop.txt` shows `Could not set the block` spam ×1525 under cgroup ≈100% (same pattern as L1 b3) but delivery proven by BATCH_DONE + 0-lost verify below.
- Settle: 60s (run 2, no autosave-watch — watch is run-1-per-jar only).
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line; pre dirty + flush 0, post 2 reads zero movement (`flush` 0→0, `movement=false`) → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced b1+b2).
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5).
- Shutdown: SIGTERM → exit = **77.4s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (`Stopping server`, `Saved all worlds`, `All RegionFile I/O tasks`); dirty_at_stop 54; 0 `Failed to flush`. Under 96 (no trigger).
- Tick: 95 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as b1; sidecars `mspt.txt` + `tick-series-*.json` 0 pairs + `tick-cooked.json`).
- Mem: 883 samples ~1Hz: heap steady **2284** / peak **2990** (= Xmx 3072 near-saturated, no ExitOnOOM — exit 143 proves it); rss steady 5451 / peak (HWM) 6139; **nmt committed peak 6515** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only, same precedent).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs staged EXPECTED-6 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`** (`verify.json` in mirror `samples/6-baseline-2/`). `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=13` (df_floor gate 13 at 16:30:54Z; CSV initially read -1 — stopped-container exec artifact at AXIS start, corrected to the gate value with this note) → `free_after_wipe_gib=13` (per-run wipe: logs/cache/crash-reports only, tree stays; floor holds).
- Sidecars: mirror `samples/6-baseline-2/` 25 files (EDITLOGs, EXPECTED×2, panels, stats, mem-series 883, tick-series, verify, tail-stop, runner log) synced BEFORE wipe.

## Provisional verdict (rules: scripts/render-stress-table.py header)

`IN PROGRESS (baseline n=2 provisional — NOT a level verdict)` — shutdown median 75.9s (74.4, 77.4) <96 (no trigger); cgroup 6144.0 = 100% cap → WARN-side `peak>=85%` datum (same as L1/L3). Load 377.4→355.0 (b1 cold-ish excluded from warm medians per §5; single warm datum 355.0s so far). No ❌ (both exits 143, 0 lost, 0 failures, 0 OOM, fallback 0). STOP+REPORT triggers: none (floor 13≥8 holds, level_confirmed=6, no ❌) — CONTINUE to b3.

## Run b3 (warm, last baseline) — baseline run 3 done 2026-09-23 17:01:23Z→17:26:06Z (driver `loop4-P0-mirror/l6wrap.py b3`; loopback console, NO jar swap — shadow already baseline e609c1d4)

- Gates re-verified: free **13 GiB ≥ 8 floor** (host-df fallback — stopped-container exec artifact fixed in wrapper; abort <8 never triggered); lock = standing `sleep 200000` reservation (no active driver — precedent: no second lock, no break); jar baseline `e609c1d4` (shadow + node, 60532041 B); config `compression-level: 6` + globals threads 1/workers 0/LDM 0/freq 10/log-batches true; NMT **ON**; pristine 16/16 sha OK (double restore); EXPECTED-6 6144 keys + `commands-y319.txt`; patched plugin `21997aad`; `smp1_players=-1` (smp-1 STOPPED by owner, no live-log lines — honest unknown); `nbtlib` local.
- Boot: restore 17:01:28Z → start → `Done` → `boot_s=10.981`; baseline plain panel + config 6 + 0 fallback → `level_confirmed=6` (patient-linearstats: first try clean, no retry needed).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=354.7` (batch-1 acks 3350 head-start from b2 log tail, +300/batch to 6144 at batch 10 proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, `load_s=-283.5` DISCARDED by design.
- Settle: 60s (run 3, no autosave-watch — watch is run-1-per-jar only).
- Save-all: `save-all flush` POST → `{"ok":true}`; 90s capped poll, NO completion line; pre dirty + flush 0, post 2 reads zero movement (`movement=false`) → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced b1+b2+b3).
- Flush: baseline plain panel → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); no batch lines (expected per spec 33 §3.5).
- Shutdown: SIGTERM → exit = **74.3s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 54; 0 `Failed to flush`. Under 96 (no trigger).
- Tick: 95 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as b1/b2).
- Mem: 872 samples ~1Hz: heap steady **1254** / peak **2948** (under Xmx 3072 — NOT saturated, like b1); rss steady 5409 / peak (HWM) 6144; **nmt committed peak 6539** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-6 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=13` (host-df fallback gate) → `free_after_wipe_gib=10` (per-run wipe: logs/cache/crash-reports only, tree stays; floor 10≥8 holds). **Neighbor note (NOT test footprint): prominence-2 (fabric, unrelated project) crashed mid-run — `core.666` 2.6G written 17:25Z + fresh 400M mrpack 17:24Z. If it dumps again during r-runs, free could approach the floor — watch per-run df, STOP on breach.**
- Sidecars: mirror `samples/6-baseline-3/` 25 files (EDITLOGs, EXPECTED×2, panels, stats, mem-series 872, tick-series, verify, tail-stop, runner log) synced BEFORE wipe.

## Baseline FINAL medians (3/3) + provisional verdict

- Baseline FINAL (n=3): `lvl 6, n=3, WARN, shutdown 74.4s, why=peak>=85%` (renderer). Boot warm median 10.7s (b2 10.453 + b3 10.981; b1 cold-ish 9.749 excluded); load warm median 354.9s (b2 355.0 + b3 354.7; b1 377.4 calibration excluded); shutdown median 74.4s (74.4, 77.4, 74.3); dirty median 54 (55,54,54); lost 0+0+0; exits 143×3; flush p50/p99 absent (correct); save n/a ×3; tick -1 ×3; cgroup 6144.0 (100% cap, reclaimed, no OOM).
- vs L1/L3 baselines: shutdown 74.4s vs 80.0 (L1) / 80.3 (L3) — **−7%, −5.6s under L1**; dirty 54 vs 55/56; load 354.9 vs 354.8/354.9 (identical, decode-independent as expected); lost 0/6144 all runs. Level-6 compresses smaller (16.37% saved vs #1) AND shuts down faster — direction favorable for the proposed default, verdict pending rc + kills.
- `WARN (baseline FINAL n=3 — axis half COMPLETE)` — no shutdown trigger (74.4 <96); no ❌. Level verdict PENDING (need 3 rc + 2 kills). STOP+REPORT triggers: none (floor 10≥8 holds, level_confirmed=6, no ❌) — CONTINUE to r1 (first rc: swap shadow→rc2 b0ea2048 via `p0run.py swap`).

## Run r1 (rc, autosave-watch) — rc run 1 done 2026-09-23 17:41:32Z→18:08:30Z (driver `loop4-P0-mirror/l6wrap.py rc1`, FIRST rc run — jar swap baseline→rc2 included; loopback console)

- Swap (rc1 only): host-fetch rc2 `CACHED b0ea20484d85` (jars pre-staged, no :ro write) → `sha256sum -c` `rc.jar: OK` → cp to shadow + node jars → swap-boot 10.258s. Live stack untouched (smp1 log read only; smp-1 stays STOPPED by owner).
- Gates re-verified: free **10 GiB ≥ 8 floor** (abort <8 never triggered, 10→10); lock = standing `sleep 200000` reservation (precedent: no second lock, no break); config `compression-level: 6` + globals threads 1/workers 0/LDM 0/freq 10/log-batches true; pristine 16/16 sha OK (double restore); EXPECTED-6 6144 keys + `commands-y319.txt`; patched plugin `21997aad`; NMT **ON**; `nbtlib` local.
- Boot: restore → start → `Done` → `boot_s=10.178`; rc panel `lvl 6` on all 3 dims + 0 `[region-format]` fallback → `level_confirmed=6` (spec 32 §4 rc source).
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=354.4` (batch-1 acks 3179 head-start from b3 log tail, +300/batch to 6144 at batch 11 proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, `load_s=-419.1` DISCARDED by design.
- Age-wait (autosave-watch, run-1 per jar): 15s (rc age gate) + 65s, flush 9→9 + dirty 54→54 → `autosave_reaches_flush=false`. Periodic age-flush (m0017) did NOT move counters in this settle window — the dirty drop below comes later (save window + shutdown drain).
- Save-all: `save-all flush` POST → `{"ok":true}`; 150s capped poll, NO completion line; pre dirty 54 + flush 9, post flush 79 (movement true = background age-flush, NOT save-all effect) → `save_all_s=n/a (never-invoked)` per spec 33 §7 (cite 03-H2, 03-H3; C3 reproduced on rc — save-all still no completion line even with m0017/counters).
- Flush: rc panel (9 folders, all `lvl 6`): prestop dirty **40** vs baseline median 54 — **−26%**; overall `flush_p50/p99=1000/1000ms` (OW + nether region 1000/1000; entities 10–25, end region 50/250); `flush_failures=0`.
- Shutdown: SIGTERM → exit = **74.3s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 40; 0 `Failed to flush`. Under 96 (no trigger; **equals the baseline median 74.4s** — no shutdown delta yet on n=1).
- Tick: 104 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as b1/b2/b3).
- Mem: 960 samples ~1Hz: heap steady **1788** / peak **3028** (near Xmx, no ExitOnOOM — exit 143 proves it); rss steady 5391 / peak (HWM) 6123; **nmt committed peak 6332** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-6 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=10` → `free_after_wipe_gib=10` (per-run wipe: logs/cache/crash-reports only, tree stays in `smp-test` volume for r2/r3; floor holds; prominence-2 quiet this run — no new core).
- Sidecars: mirror `samples/6-rc-1/` 27 files (EDITLOGs, EXPECTED×2, panels incl. autosave-watch, stats, mem-series 960, tick-series, verify, tail-stop, runner log) synced BEFORE wipe.

## Provisional verdict (rules: scripts/render-stress-table.py header)

`WARN (baseline FINAL n=3 unchanged + rc n=1 provisional)` — baseline medians stay `lvl 6, n=3, WARN, shutdown 74.4s, why=peak>=85%` (renderer line above untouched). rc r1 provisional (NOT a level verdict): shutdown 74.3s <96, dirty 40 (−26% vs baseline 54), lost 0, exit 143, 0 failures — direction matches the m0017 age-flush expectation (cut dirty; shutdown delta pending n=3) but n=1 proves nothing yet; need r2+r3 + 2 kills. No ❌ (single ❌ would mark the level — none seen). STOP+REPORT triggers: none (floor 10≥8 holds, level_confirmed=6, no ❌) — CONTINUE to r2.

## Run r2 (rc, warm) — rc run 2 done 2026-09-23 18:11:04Z→18:36:45Z (driver `loop4-P0-mirror/l6wrap.py rc2`; NO jar swap — shadow already rc2 b0ea2048 since r1; loopback console)

- Gates re-verified: free **10 GiB ≥ 8 floor** (abort <8 never triggered); lock = standing `sleep 200000` reservation (precedent); jar rc2 `b0ea2048` (shadow + node, no swap); config `compression-level: 6` + globals; NMT **ON**; pristine 16/16 sha OK (double restore); EXPECTED-6 + `commands-y319.txt`; plugin `21997aad`; `smp1_players=-1` (smp-1 still STOPPED by owner).
- Boot: restore → start → `Done` → `boot_s=9.948`; rc panel `lvl 6` all dims + 0 fallback → `level_confirmed=6`.
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=354.6` (batch-1 acks 3285 head-start from r1 log tail, +300/batch to 6144 at batch 11 proves fresh; C6 future-skipped=0); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design.
- Settle: 60s (run 2, no autosave-watch — watch is run-1-per-jar only).
- Save-all: `save-all flush` POST → `{"ok":true}`; 150s capped poll, NO completion line; pre dirty + flush 9, post flush 77 (movement true = background age-flush, NOT save-all effect) → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced b1+b2+b3+r1).
- Flush: rc panel (9 folders, all `lvl 6`): prestop dirty **41** vs r1 40 / baseline 54 — **−24% vs baseline**; overall `flush_p50/p99=1000/1000ms`; `flush_failures=0`.
- Shutdown: SIGTERM → exit = **71.3s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 41; 0 `Failed to flush`. Under 96 (no trigger; **3.1s under the baseline median 74.4s, 3.0s under r1**).
- Tick: 99 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as all prior runs).
- Mem: 921 samples ~1Hz: heap steady **1374** / peak **3072** (= Xmx, saturated); rss steady 5400 / peak (HWM) 6116; **nmt committed peak 6402** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-6 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=10` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays; **prominence-2's 2.6G core + mrpacks were cleaned by the owner mid-window — NOT test footprint**; floor holds throughout).
- Sidecars: mirror `samples/6-rc-2/` 26 files (EDITLOGs, EXPECTED×2, panels, stats, mem-series 921, tick-series, verify, tail-stop, runner log; no autosave-watch — run 2) synced BEFORE wipe.

## Provisional verdict (rules: scripts/render-stress-table.py header)

`WARN (baseline FINAL n=3 unchanged + rc n=2 provisional)` — baseline medians stay `lvl 6, n=3, WARN, shutdown 74.4s, why=peak>=85%` (renderer line above untouched). rc provisional n=2 (NOT a level verdict): shutdown median 72.8s (74.3, 71.3) <96, dirty 40→41 (−26%→−24% vs baseline 54), load median 354.5s (354.4, 354.6), boot median 10.1s (10.178, 9.948), lost 0+0, exits 143+143, 0 failures — m0017 age-flush direction holds across both rc runs; need r3 + 2 kills. No ❌ (single ❌ would mark the level — none seen). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=6, no ❌) — CONTINUE to r3.

## Run r3 (rc, warm, last axis run) — rc run 3 done 2026-09-23 18:38:34Z→19:04:19Z (driver `loop4-P0-mirror/l6wrap.py rc3` + C6 guard; NO jar swap — shadow already rc2 b0ea2048 since r1; loopback console)

- Gates re-verified: free **14 GiB ≥ 8 floor** (abort <8 never triggered, 14→14); lock = standing `sleep 200000` reservation (precedent); jar rc2 `b0ea2048` (shadow + node, 60541066 B, no swap); config `compression-level: 6` + globals; NMT **ON**; pristine 16/16 sha OK (double restore); EXPECTED-6 + `commands-y319.txt`; plugin `21997aad`; `smp1_players=-1` (smp-1 still STOPPED by owner); `nbtlib` local.
- Boot: restore → start → `Done` → `boot_s=10.238`; rc panel `lvl 6` all dims + 0 fallback → `level_confirmed=6`.
- Load: forceload 24-add recipe → query **4096/1024/1024 exact** (both passes); pass 1 staged 6144 EDITs in 21×300 batches → `load_s=355.0` DIRECT (no midnight correction; C6 guard armed, `future-skipped=0` all 21 batches; batch-1 acks 3342 head-start from r2 log tail, +300/batch to 6144 at batch 11 proves fresh); pass 2 redirty identical setblocks → all 21 BATCH_DONE, pass-2 timing DISCARDED by design.
- Settle: 60s (run 3, no autosave-watch — watch is run-1-per-jar only).
- Save-all: `save-all flush` POST → `{"ok":true}`; 150s capped poll, NO completion line; pre dirty + flush 9, post flush 79 (movement true = background age-flush, NOT save-all effect) → `save_all_s=n/a (never-invoked)` per spec 33 §7 (C3 reproduced b1+b2+b3+r1+r2).
- Flush: rc panel (9 folders, all `lvl 6`): prestop dirty **40** vs r1 40 / r2 41 / baseline 54 — **−26% vs baseline**; overall `flush_p50/p99=1000/1000ms`; `flush_failures=0`.
- Shutdown: SIGTERM → exit = **72.3s**, `ExitCode=143` clean, `OOMKilled=false` (docker wait BEFORE step-7 restart); clean checklist in `tail-stop.txt` (3 markers); dirty_at_stop 40; 0 `Failed to flush`. Under 96 (no trigger).
- Tick: 99 `mspt` polls, **0 response pairs** → `tick_p99_ms=-1` reason `mspt-no-response` (same as all prior runs).
- Mem: 921 samples ~1Hz: heap steady **2524** / peak **3072** (= Xmx, saturated); rss steady 5379 / peak (HWM) 6134; **nmt committed peak 6699** (NMT on); **cgroup 6144.0 MiB = 100.0% of 6GiB** — cap touched, reclaimed, NO OOM kill. 95% guard flagged throughout (flag only).
- Safety (REAL decode-back verify, step 7): post-shutdown fetch of 6 region files BEFORE restart → reboot → local `linear2mca` per-dim (errors=0) → `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED-6 + EDITLOG-2: **6144 ok / 0 missing / 0 stale / 0 unknown → `chunks_lost=0`**. `flush_failures=0`; `level_fallback_severe=0`.
- Disk: `free_before_gib=14` → `free_after_wipe_gib=14` (per-run wipe: logs/cache/crash-reports only, tree stays in `smp-test` volume; floor holds).
- Sidecars: mirror `samples/6-rc-3/` 26 files (EDITLOGs, EXPECTED×2, panels, stats, mem-series 921, tick-series, verify, tail-stop, runner log; no autosave-watch — run 3) synced BEFORE wipe.

## rc FINAL medians (3/3) + axis verdict baseline-vs-rc

- Baseline FINAL (n=3): `lvl 6, n=3, WARN, shutdown 74.4s, why=peak>=85%` (renderer). Boot warm median 10.7s (b2 10.453 + b3 10.981; b1 cold-ish 9.749 excluded); load warm median 354.9s (b2 355.0 + b3 354.7; b1 377.4 calibration excluded); shutdown median 74.4s (74.4, 77.4, 74.3); dirty median 54 (55,54,54); lost 0+0+0; exits 143×3; flush p50/p99 absent (correct); save n/a ×3; tick -1 ×3; cgroup 6144.0 (100% cap, reclaimed, no OOM).
- rc FINAL (n=3): `lvl 6, n=3, WARN, shutdown 72.3s, why=peak>=85%` (renderer). Boot median 10.2s (10.178, 9.948, 10.238); load median 354.6s (354.4, 354.6, 355.0); shutdown median 72.3s (74.3, 71.3, 72.3); dirty median 40 (40,41,40); lost 0+0+0; exits 143×3; flush p50/p99 1000/1000 ×3; save n/a ×3; tick -1 ×3; cgroup 6144.0 (100% cap, reclaimed, no OOM).
- Full renderer lines:
  - `lvl 6, n=3, WARN, shutdown 74.4s, tick n/a, flush n/a, save n/a, cgroup 6144MiB, size 14887028404B, vs_anvil 0.571, saved_vs_#1 16.37%, why=peak>=85%` (baseline)
  - `lvl 6, n=3, WARN, shutdown 72.3s, tick n/a, flush 1000.0ms, save n/a, cgroup 6144MiB, size 14887028404B, vs_anvil 0.571, saved_vs_#1 16.37%, why=peak>=85%` (rc)
- Axis verdict (baseline-vs-rc): shutdown 74.4→72.3s (**−3%, −2.1s**); dirty 54→40 (**−26%**); load 354.9→354.6 (no change, decode-independent as expected); boot 10.7→10.2s (no change); lost 0/6144 all 6 runs; exits 143×6; flush_fail 0×6; OOM 0×6; fallback 0×6. m0017 age-flush direction holds across all 3 rc runs. No ❌ (single ❌ would mark the level — none seen). star=none (needs all-clear level). STOP+REPORT triggers: none (floor 14≥8 holds, level_confirmed=6, no ❌) — axis COMPLETE, CONTINUE to 2 kill rows (SIGKILL T+30 × baseline+rc2, run=91; OOM skipped per C7).

## Provisional verdict (rules: scripts/render-stress-table.py header)

`WARN (baseline FINAL n=3 + rc FINAL n=3 — axis COMPLETE)` — baseline `shutdown 74.4s, why=peak>=85%`; rc `shutdown 72.3s, why=peak>=85%`. No shutdown trigger (both <96); no ❌. Level verdict PENDING (need 2 kills: k_bskill/k_rskill per L6 charter, SIGKILL T+30 only, EDITLOG + chunks-lost-verify, loss_window_s). Tree stays in `smp-test` volume for kills; `level-6/` holds manifests + pristine + EXPECTED + commands + backups.

## Run b2 (warm)

baseline run 2 done: boot=10.453 load=355.0 save=-1 shut=77.4 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0

## Run b3 (warm)

baseline run 3 done: boot=10.981 load=354.7 save=-1 shut=74.3 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0

## Run r1 (rc, autosave-watch)

rc run 1 done: boot=10.178 load=354.4 save=-1 shut=74.3 exit=143 lost=0/6144 dirty=40 tick=-1 cgroup_peak=6144.0

## Run r2 (rc)

rc run 2 done: boot=9.948 load=354.6 save=-1 shut=71.3 exit=143 lost=0/6144 dirty=41 tick=-1 cgroup_peak=6144.0

## Run r3 (rc)

rc run 3 done: boot=10.238 load=355.0 save=-1 shut=72.3 exit=143 lost=0/6144 dirty=40 tick=-1 cgroup_peak=6144.0
