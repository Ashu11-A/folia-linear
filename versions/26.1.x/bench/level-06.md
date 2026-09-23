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

## Runs (IN PROGRESS — 1/8: baseline b1 done, b2+b3 + 3 rc + 2 kills pending)

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 (cold-ish) | 9.7 | 377.4 (per-chunk; 6144/6144 Changed; C1+C2 recipes; L3-log-tail head-start caveat) | n/a (never-invoked; 90s cap, 0 completion; 03-H2/H3) | -/- (baseline absent, correct) | 55 | 74.4 | 143/0 | -1 (mspt-no-response; 93 polls, 0 pairs) | heap 1386/2850, rss 5324/6140, nmt 6539, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |

CSVs: 1 row appended (test=6 baseline run 1); sidecars in mirror `samples/6-baseline-1/` (26 files, mem-series 806). Per-run wipe done (logs/cache only, tree stays in `smp-test` volume); `free_after_wipe_gib` 14 via driver `clean_run`.

Medians (renderer-computed; warm medians for boot/load per agent 32 §6):
`n/a — n=1, no medians yet (provisional: shutdown 74.4s <96, no trigger; cgroup 6144.0 = 100% cap → WARN-side peak>=85% datum)`

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
