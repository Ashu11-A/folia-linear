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
