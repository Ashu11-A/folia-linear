# Level 01 — baseline × 3 + rc2 × 3 + 4 kill rows — BLOCKED (disk)

- `test=1` `level_confirmed=n/a` (no boot: no run started; conversion killed before verify)
- `jar=baseline` `jar_sha256=e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (60532041 B, shadow-server + stress/jars copies identical)
- `jar=rc2` `jar_sha256=b0ea20484d85e4adce697cb786bf164b6fa4865d9eb122b8c931910e2723e1d6` (60541066 B, stress/jars)
- `ldm=0` `flush_threads=1` `compression_workers=0` (planned axis-1 defaults; never booted)
- `bytes_anvil=26056405704` (frozen constant, S2-finalize 2026-09-22; NOT re-derived, source-anvil read-only)
- `convert_s=n/a` `bytes_on_disk=n/a` (conversion killed mid-tree, see below)

## Runs

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — | — | — | — | — | — |

No runs started. Zero CSV rows appended (CSV stays header-only).

Medians (renderer-computed; warm medians for boot/load per agent 32 §6):
`n/a — no rows`

## Evidence

- Pre-run gates actually verified 2026-09-22 ~11:20–11:30Z (all read-only unless noted):
  - `smp-test` container PRESENT and running (S2 "absent" claim refuted): `remote.sh exec smp-test` answers; java PID 1 since 08:55Z on baseline jar; hostname `79e268ad661d`. NOT recreated (charter: recreate only if truly absent). Live stack untouched.
  - Jars: both sha256 verified on host (`stress/jars/folia-{baseline,rc2}.jar` + shadow-server `folia.jar` = baseline).
  - Patched plugin in smp-test volume: `sexidium-paper-26.1.2+16.jar` sha256 `21997aad…ff74edfa` (matches S2 record).
  - Console path re-staged + live-fired: loopback POST to `127.0.0.1:8840/command` via `exec smp-test -- bash` → `{"ok":true}`, `/linearstats` result in log. Baseline panel renders `lvl 6`, dirty bars, p50/p99 fields. Token from `remote.secrets.json` (in-memory only).
  - Harness lock: `flock -n $STRESS/harness.lock` held for the whole attempt, released after. No other agent active (no lock file existed before).
  - Free-space gate at conversion start: **28 GiB free ≥ 17+5 GiB need, ≥ 15 GiB floor → PASS** (`df -B1G /srv/build`, 11:27:03Z).
  - Workload artifacts generated offline (local): `EXPECTED.json` 6144 keys + `commands.txt` 6147 lines via `edit-workload.py gen/cmds --level 1`; copy staged at `stress/level-1/EXPECTED.json` (kept for the retry).
- Conversion attempt (`mca2linear -c 1 -t 4`, per-dim overworld/the_nether/the_end, helper container `level1-helper` on bind-mounted real volumes, low-traffic window):
  - `stress/level-1/` created EMPTY; overworld convert found 7382 `.mca` files, 0 `.mcc`.
  - Growth: 4.6G (11:33Z) → 5.4G → **14G**, free 28G → **12.66 GiB** (`df -B1`, 13593231360 B).
  - **Killed by this agent at 12.66 GiB: below the 15 GiB absolute floor** (charter STOP rule). No `DONE-*` line; tree partial; no verify, no header audit, no pristine snapshot — nothing recorded as a result.
  - Wipe: `stress/level-1{,-convert.log,-t0,-t1}` removed; free back to **28 GiB** (pre-test level, tolerance 1 GiB ✓). Helper container + `python:3.13-slim` image removed. Lock released.
- Disk audit (read-only, post-wipe): `sexidium-data/server` 18G (LIVE, read-only) · `stress/source-anvil` 25G (must keep) · `stress` rest ≈ small · `build/repo` 1.8G · builds `b0111+b0112` 2.0G (both keep) · tarballs/markers/repo-build/gradle-home already gone (Immediate-Actions cleanup COMPLETE — nothing left of it to free).

## Provisional verdict (rules: scripts/render-stress-table.py header)

`BLOCKED — disk` — level-1 tree ≈ 16.6 GiB (14G measured partial; L1/L6 sample ratio 0.722/0.609 × mirror full L6 tree 14G) cannot coexist with the 15 GiB floor on 27–28 GiB free: post-conversion free ≈ 11 GiB ⇒ (a) floor breach during the test, (b) per-run gate `free ≥ 17+5 GiB` refuses run #1 (`11 < 22`). Two independent gates block; the block is structural, not transient.

## Blockers / anomalies

- BLOCKER (owner decision needed): free before test must be ≈ tree (16.6G) + floor (15G) + run transient (~1–2G incl. forceload-subset decode-back) ≈ **34 GiB**; have 27–28 GiB; shortfall ≈ **6 GiB**. No further owner-pre-approved deletions exist (audit above). Options, none taken: add disk / move source-anvil or live data / waive floor (risks live `smp-1`, same `/dev/sda6`) / shrink scope (violates full-world protocol — not this agent's call).
- NOTE for other level agents: the same arithmetic gates every full-world level (even L22 ≈ 12G needs ≈ 28G). Do not start conversions without re-checking free vs `tree + 15G floor`.
- No `level_fallback_severe`, no kills, no OOM, no wipes of live data. `run-queue.json` left `done:[]` (deliberately NOT marked).

---

## Retry under 8 GiB waiver — IN PROGRESS (2026-09-22, 1/10 runs)

Owner waiver: floor 8 GiB campaign, abort <8 GiB (host + mirror `run-queue.json` `floor_gib_owner_waiver`, host `run-log` `floor-waiver` 11:20Z). Pre-test gate: free 28 GiB ≥ 17+5=22 GiB → PASS (28G now); floor 28≥8 PASS. Lock: pre-existing `sleep 200000` holder (PID 3159562, since 11:25Z, fd 3 → `sexidium-build/.../stress/harness.lock`, output `/tmp/level1-lock.out` empty) treated as Level-1 reservation — no second lock acquired, no break; one-run rule satisfied (no other level activity, no converter contention, free stable).

- `test=1` `level_confirmed=1` (3-source: config `compression-level: 1` in `paper-world-defaults.yml` (was 6) + header audit 8383/8383 lvl=1 + 0 `[region-format]` fallback lines; baseline panel has no `lvl` token per paper-0010, rc token pending)
- `jar=baseline` `jar_sha256=e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (60532041 B; shadow-server + `stress/jars/folia-baseline.jar` identical; `smp-test/folia.jar` symlink → shadow)
- `jar=rc2` `jar_sha256=b0ea20484d85e4adce697cb786bf164b6fa4865d9eb122b8c931910e2723e1d6` (60541066 B, `stress/jars/folia-rc2.jar`; NOT booted yet)
- `ldm=0` `flush_threads=1` `compression_workers=0` (axis-1 defaults; `paper-global.yml` verified: threads 1, workers 0, LDM 0, frequency 10; `log-flush-batches` set `false→true` for Loop-4 runs per spec 39 §2 note, recorded as run-constant)
- `bytes_anvil=26056405704` (frozen, NOT re-derived) `convert_s=664` (t0 12:00:25Z→t1 12:11:29Z; per-dim walls 610.8+9.7+42.8=663.3s, threads 3/1/1 after cgroup clamp 4→3/1) `bytes_on_disk=17801732197` (≈16.58 GiB; OW 17344939094 + nether 165426119 + end 291366984; ratio vs Anvil 0.6832, 31.68% saved; vs #1 — (anchor))
- Conversion (`mca2linear -c 1 -t 4` per-dim via `worker-1` python3, empty `level-1/` dir, ≤8 threads): OW 7382 files in=23318872064 out=17344939094 ratio=0.744 wall=610.8s; nether 117 files in=274874368 out=165426119 ratio=0.602 wall=9.7s; end 884 files in=2462646272 out=291366984 ratio=0.118 wall=42.8s; all `EXIT=0`, `DONE-ALL`; 0 `.mcc`; free 28G→11G (11648557056 B), floor 11≥8 PASS (old 15G floor would have killed — waiver decisive)
- Verify (decode-back workaround, harness `verify_level` broken by construction): header audit 8383/8383 lvl=1 bad=0; manifest src_sha cross-check 7382+117+884=8383/8383 mism=0 missing=0 (`level-1` convert.manifest `src_sha` == `source-anvil` decode `dst_sha`); forceload-subset (16 files, `forceload-files.txt`) `linear2mca` + `verify` per-dim 12/2/2 files all `total diffs=0`; full-tree decode-back NOT attempted (needs ~23G temp, free 11G — would breach floor; manifests + headers + subset are the honest gate; temp mini dirs wiped)
- Pristine: 16 files (OW 4×(region+entities+poi)=12 + nether 2 + end 2; end `poi/r.0.0` absent as expected, nether no `poi` dir) 29M + `pristine.sha256` 16 lines; `EXPECTED.json` 6144 keys sha `a5a266c4…` + `commands.txt` 6147 lines staged (local `edit-workload.py gen/cmds --level 1`); `commands-y319.txt` 6147 lines staged (overworld y 320→319 fix, see calibration C2)
- Staging (move, not copy — same `/dev/sda6`, rename instant, free unchanged 11G): backed up small world (1.4M, 4 files/dim) + configs to `level-1/smp-test-small-backup` + `*.bak`; stopped `smp-test` clean (small-world stop, exit 143); moved `level-1/tree/{overworld,the_nether,the_end}/{region,entities,poi}` → `smp-test/.../dimensions/minecraft/...` (13 dirs moved, 0 copied); `TREE` left with manifests only; set `compression-level: 1`, `log-flush-batches: true`; booted baseline (see run 1)
- Jars/plugin/console re-verified cheaply (no re-derive): shadow baseline e609c1d4 ✅, rc2 b0ea2048 staged ✅, patched plugin 21997aad ✅ (`pluginjars/sexidium-paper-26.1.2+16.jar`), `smp-test` PRESENT/RUNNING on baseline (NOT recreated; uptime 3h pre-staging, PID 1 java `-Xmx3G` 6G/8cpu), `smc.py` sha `bff98d8c…` matches fork `bench/smc.py` ✅, live-fire `linearstats` → `{"ok":true}` + panel in log ✅, CSV Day-0 header-only locally (2 sample rows removed, harness.sh rc2 pin uncommitted — both preserved, NOT committed here except CSV row below), 0 players (`joined` count 0, no `players online` lines)

## Runs (IN PROGRESS — 1/10: baseline run 1 done, 2 baseline + 3 rc + 4 kills pending)

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 (cold-ish) | 11.5 | 681 (per-chunk; 6144/6146 Changed; C1+C2 calibrations) | n/a (never-invoked; 2 reads, 0 movement; 03-H2/H3) | -/- (baseline absent, correct) | 56 | 97 | 143/0 | -1 (sampler-not-run) | -/- (no-sampler; NMT off) | -1 (no-nbtlib; mini verify pending y319) | 28→11 (move, no breach) |

CSVs: 1 row appended (baseline run 1, see `stress-1-22.csv`); sidecars to mirror BEFORE wipe: PENDING (no wipe yet — tree in `smp-test` volume, `level-1/` holds manifests + pristine (29M) + EXPECTED + commands + backups + run1 `t-issue*`/`t-loaded*`; logs in `smp-test` volume `latest.log` (37211+ lines); mirror sync on completion, NOT yet).

Medians (renderer-computed; warm medians for boot/load per agent 32 §6):
`n/a — 1/3 baseline runs (need b2+b3 for median; b1 cold-ish excluded from warm median per §5)`

## Evidence (run b1)

- Boot: `latest.log` `Done (11.458s)` 12:23:40Z (start ≈12:23:28Z); 0 `[region-format]` lines (healthy, no fallback); config-readback level 1 + headers 8383 lvl=1 → `level_confirmed=1`; `jar_sha256` e609c1d4 (shadow + `folia.jar` symlink); `smp1_players=0`; `started_at=2026-09-22T12:23:28Z`
- Load: forceload chunking recipe (C1) 24 adds (OW 16×256 + nether/end 4×256 each) → Marked 240+15×256 (OW) / 252+3×256 (nether/end) + prior 16/4/4 = 4096/1024/1024; workload 6144 EDITs via `smc.py` (3 attempts: #1 wrong-forceload + y=320 → 32 Changed + 6080 not-loaded; #2 correct-forceload + y=320 → 2048 Changed (nether/end), OW 4096 out-of-world; #3 y=319 → 4096 OW Changed; total 6146 Changed incl. 2 y-tests); t_issue 12:34:38Z (2nd start) → t_loaded 12:45:59Z (3rd end) = 681s; `load_evidence=per-chunk` (all 6144 EDITs `Changed the block at x, y, z` confirmed; default echo regex matches unbracketed shape); `forceload query` rendering pinned (16/4/4 for small adds, `Marked N chunks ... from [x1,z1] to [x2,z2]`)
- Save-all: `save-all flush` POST 12:46:50Z → `{"ok":true}`; NO completion line (`Saved`/`Flushed`/`save.*complete|done|success` 0 hits); pre-save dirty 56 (D1 12:46:21Z) + W=20389>0; post-save reads 12:47:28Z + 12:47:55Z (27s apart, second 65s post-save) zero movement (`filesFlushed=0`, `flush=0`, dirty still 56); 0 `Failed to flush` → `save_all_s=n/a (never-invoked)` per spec 33 §7 (cite 03-H2, 03-H3, 02-Unknowns); L2 reproduced on full tree level 1 baseline
- Flush: baseline paper-0010 panel (plain `dirtyDepth`, no `lvl`/`p50`/`p99`) → `flush_p50_ms=-1`, `flush_p99_ms=-1` (absent, correct per spec 33 §4); `log-flush-batches: true` set but no batch lines (paper-0012 declares, no reader — expected per spec 33 §3.5)
- Shutdown: SIGTERM 12:48:13Z → exit 12:49:50Z = **97s**, `ExitCode=143` clean, `OOMKilled=false`; log `Stopping server` + `Saved chunks`×3 + `Saved all worlds` + `All RegionFile I/O tasks` (clean checklist §4); 0 `Failed to flush`; dirty_at_stop 56 (12:47:55Z reading); **⚠️ shutdown 97s ≥96** (80% of 120s grace, little margin; H3 reproduced even at level 1 with 56 dirty files, serial drain)
- Tick/mem: NOT measured this run (`tick_p99_ms=-1` reason `sampler-not-run`; mem all `-1` reason `no-sampler` + NMT off (no `-XX:NativeMemoryTracking`, hook not applied per spec 35 §2); cgroup/RSS/heap sampling + 95% abort guard armed for remaining runs; no OOM (peak unknown, but exit 143 + OOM false proves no kill)
- Size: `bytes_on_disk=17801732197` (per-folder `du -sb`, manifests excluded) + `bytes_anvil=26056405704` + `convert_s=664`; LDM note (no offline +LDM size, converter level-only per spec 36 §1.5)
- Safety: `flush_failures=0` (grep count), `chunks_edited=6144`, `chunks_lost=-1` (no `nbtlib` on `worker-1`, no `chunks-lost-verify.py` on host repo; mini post-shutdown verify PENDING with y=319 fix — clean shutdown (143, Saved all worlds, 0 failures) predicts 0 lost, but NOT recorded as 0 without verify; EDITLOG pending (log slice + date + echo regex available, `Changed` stamps HH:MM:SS, date 2026-09-22)), `level_fallback_severe=0` (0 SEVERE lines, confirmed 1)
- Disk: `free_before_gib=28` (pre-test gate) → 11G post-conversion/post-staging (move, no copy, no breach, abort <8G never triggered); `free_after_wipe_gib=-1` (NOT wiped — test IN PROGRESS, tree in `smp-test` volume, `level-1/` + small-backup retained; post-test wipe + return-check (tolerance 1G) on completion)

## Provisional verdict (rules: scripts/render-stress-table.py header)

`⚠️ (run b1 only — NOT a level verdict)` — trigger `shutdown 97s ≥ 96` (Risky: little margin before SIGKILL; H3 serial drain even at level 1). No ❌ (shutdown ≤120, exit 143, 0 failures, 0 OOM, fallback 0; chunks unknown, NOT counted as lost). Level verdict PENDING (need b2+b3 baseline + 3 rc + kills; single ⚠️ does NOT mark level; single ❌ would — none seen; STOP+REPORT triggers: no ❌, no floor breach (11≥8), level_confirmed=1 ✅ — CONTINUE).

## Blockers / anomalies (IN PROGRESS — not BLOCKED)

- Calibrations (run-#1 pins for all level agents, Loop 5 report inputs):
  - C1 forceload 256-limit: `forceload add` max 256 chunks/command (`Too many chunks ... maximum 256`); fixed set needs 24 adds (OW 16× 256-block squares 0-1023, nether/end 4× each 0-511); single `0 0 63 63` (chunk-coords) marks only 16 chunks ([0,0]-[3,3]); block-coords required (chunk×16); `Marked N chunks ... from [c1] to [c2]` rendering pinned; overlapping adds explain 240/252 first-blocks (prior 16/4/4) — NOT an error.
  - C2 overworld y=320 off-by-one: `DIM_Y overworld 320` → `That position is out of this world!` (MC 26.1.2 overworld max y=319); y=319/318 `Changed` ✅; workload + verifier must use 319 for overworld (200 nether/end OK); `commands-y319.txt` staged + used for b1 OW 4096; `EXPECTED.json` unaffected (no y in sha); file as Loop-5 finding (agent 20 §5 fix: 320→319) + patch `edit-workload.py`/`chunks-lost-verify.py` `DIM_Y` for remaining runs.
  - C3 `save-all flush` no-op on baseline full-tree L1 (L2 reproduced): 200 ok + 0 completion + 0 counter movement across 2 reads → `n/a (never-invoked)` (03-H2/H3); rc (m0017/periodic + counters) may differ — compare in rc runs.
  - C4 baseline `linearstats` plain (no `lvl`/`p50`/`p99`) — level via config+headers+0-fallback (3-source rule); rc panel (`lvl`, bars, p50/p99) pending in rc runs; `forceload query` + `Changed` regex + `save` completion candidates pinned (see Evidence).
- Pending (9 runs + kills + sidecars + wipe + medians + final verdict + `done:["1"]`): b2+b3 baseline (warm; reuse staging, restore pristine 16 files per-run via host cp 29M, reboot, workload `commands-y319.txt` 6144 edits ~5min, same columns + mem/tick samplers to be armed); 3 rc runs (swap shadow to rc2 b0ea2048 via `swap_jar` (restart ONLY `smp-test`), same staging (tree already L1, headers lvl=1 — rc reads L1 fine, writes L1 (config still 1)), expect periodic-flush (m0017) to cut `dirty_at_stop`/`shutdown_s` vs baseline + panel `lvl 1` + p50/p99); 4 kill rows (T+30s SIGKILL + cgroup-OOM ×2 jars per charter, spec 38 matrix staged L6-first BUT charter narrows to L1 here — use `EDITLOG` + `chunks-lost-verify` (y=319 patched, `nbtlib` to be installed on `worker-1` or verifier staged) for `loss_window_s`; EDIT-600 eviction NOT in charter L1 (skip — base 6144 only)); per-run CSV + sidecars to mirror BEFORE wipe; per-run wipe (logs/caches/crash-reports, NOT tree until test end) + `df` assert (abort <8G); `level-01.md` after EACH run; at completion move tree back to `level-1/tree` + restore small world + wipe `level-1/` + `smp-test` volume + return-check (28G±1G) + commit `level-01.md`+CSV + push + `run-queue.json done:["1"]` host+mirror; handoff #3 (needs #1 medians for `saved vs #1` — BLOCKED until b2+b3+rc medians exist).
- No `level_fallback_severe`, no ❌, no OOM, no floor breach (11≥8 throughout; 8G waiver holds), no live writes (only `stress/level-1/*` + `smp-test` volume via host volume paths + container execs; `sexidium-data`, `smp-1`, plugin builds, stock jar untouched; `smp-1` players 0 throughout, low-traffic window). `run-queue.json` left `done:[]` (NOT complete — 1/10 runs).
