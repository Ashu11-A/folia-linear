# Level 12 — UNSAFE FINAL

## Result

- On-disk size: `bytes_on_disk=14182988894` (≈13.21 GiB; OW 13854576161 + nether 134403523 + end 194009210 out-bytes; per-folder `du -sb` minus manifests 2270364).
- Saved vs Anvil: `bytes_anvil=26056405704`; ratio 0.5443, 45.57% saved; `saved vs #1 20.33%`.
- Shutdown outcome: baseline median 84.3s (82.2, 84.3, 85.2), all exit 143; rc r1 `shutdown_s=120.9` → exit 137, `OOMKilled=false` (120s grace-expiry SIGKILL); park-stop replica 121.0s / 137 / oom 0 confirms 2/2 reproducibility.
- Chunks lost: baseline 0/6144 on b1+b2+b3 (6144 ok / 0 missing / 0 stale / 0 unknown each); rc r1 2047/6144 lost (4097 ok / 2047 missing / 0 stale / 0 unknown).
- Memory: cgroup 6144.0 MiB = 100.0% of 6GiB on b1+b2+b3+r1, reclaimed, OOM 0; heap steady/peak b1 1248/2896, b2 1436/3072, b3 2788/3072, r1 1366/3050; nmt peaks 6467, 6497, 6517, 6523; mem-series 955, 896, 910, 990 samples.

## Runs

| run | boot_s | load_s (+evidence grade) | save_all_s | flush p50/p99 | dirty_at_stop | shutdown_s | exit/oom | tick_p99 | mem steady/peak | chunks lost | free± |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b1 (cold-ish) | 10.1 | 352.5 (per-chunk; batched driver 21×300, staged EDITs; 6144/6144 acks EDITLOG-1+2; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 82.2 | 143/0 | -1 (mspt-no-response; 100 polls, 0 pairs) | heap 1248/2896, rss 5325/6139, nmt 6467, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| b2 (warm) | 10.7 | 352.1 (per-chunk; batched driver 21×300, staged EDITs; fresh +300/batch growth to 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 54 | 84.3 | 143/0 | -1 (mspt-no-response; 95 polls, 0 pairs) | heap 1436/3072, rss 5384/6116, nmt 6497, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| b3 (warm, last baseline) | 10.3 | 354.2 (per-chunk; batched driver 21×300, staged EDITs; fresh 6144 at batch 11; C6 future-skipped=0) | n/a (never-invoked; 90s cap, movement=false; 03-H2/H3) | -/- (baseline absent, correct) | 56 | 85.2 | 143/0 | -1 (mspt-no-response; 96 polls, 0 pairs) | heap 2788/3072, rss 5268/6146, nmt 6517, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 0/6144 (real nbtlib verify, 6144 ok) | 14→14 (no breach) |
| r1 (rc ❌) | 10.1 | 352.2 (per-chunk; batched driver 21×300, staged EDITs; fresh +300/batch to 6144 at batch 11; C6 future-skipped=0) | 121.3 (COMPLETED — first completion in campaign; movement=true via stats-reset 9→0, see anomaly) | 0.0/0.0 (ANOMALOUS ZEROS — post-save panel server-rendered files=0/never-flushed; presave+prestop normal 1000/1000) | 55 | 120.9 ❌ | 137/0 (SIGKILL after 120s grace, NOT OOM) | -1 (mspt-no-response; 104 polls, 0 pairs) | heap 1366/3050, rss 5339/6142, nmt 6523, cgroup 6144.0 (100% cap touched, no OOM; NMT on) | 2047/6144 (all missing, S2 tail-loss) | 14→14 (no breach) |

Axis one-liners: baseline run 1 done: boot=10.142 load=352.5 save=-1 shut=82.2 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0; baseline run 2 done: boot=10.708 load=352.1 save=-1 shut=84.3 exit=143 lost=0/6144 dirty=54 tick=-1 cgroup_peak=6144.0; baseline run 3 done: boot=10.304 load=354.2 save=-1 shut=85.2 exit=143 lost=0/6144 dirty=56 tick=-1 cgroup_peak=6144.0.

## Anomalies

- Save-all completed at `save_all_s=121.3` with `movement=true`, but movement reads `flush_before=9 → flush_after=0`: post-save panel (03:15:11, server-rendered) shows all folders `files=0`, `dirty 0/512`, `never flushed`, p50/p99 0us; presave (03:11:44) showed real data (dirty 13+1+16+3…, p50/p99 50ms–1.00s); prestop reads normal again (dirty 55, 1000/1000); no second `Done`, no `Stopping`, no OOM, no crash in the 3000-line tail window.
- Flush parser recorded `flush_p50_ms=0.0`, `flush_p99_ms=0.0` from the anomalous post-save zeros; prestop panel reads normal 1000/1000 with dirty 55.
- Shutdown crossed the 120s grace: SIGTERM → drain → exit 137, `OOMKilled=false`, `shutdown_s=120.9`; tail holds single `Stopping server` 03:21:57 plus RegionShutdownThread drain lines 03:21:57/03:23:36, no clean markers, 0 `Failed to flush`, no fallback SEVERE.
- Park-stop replica confirms reproducibility: post-verify idle server SIGTERM-stopped → 121.0s / 137 / oom 0, second consecutive SIGTERM→SIGKILL.
- Post-kill tree held 1 `.linear.tmp` orphan (`the_nether/entities/r.0.0`, kill-mid-flush signature, removed at close-out with the tree).
- Jar-swap ordering quirk: swap copies after start, so the swap-boot `Done` belongs to the pre-swap baseline boot; true rc boot is AXIS `boot_s=10.103`.
- Grading stands complete by verdict, not row count: axis holds 4 rows (b1+b2+b3+r1); r2/r3/k1/k3 never ran by owner-accepted STOP decision.
- Close-out removed the staged tree (~14.2G: OW region 13831575993 + nether region 134021727 + end region 193745043 + entities/poi) (file records both this region-only breakdown and the conversion out-bytes OW 13854576161 + nether 134403523 + end 194009210); restored the small world to 1072519 B (+39B vs pre-test 1072480, 18 small `.linear` files, no poi dirs, 0 `.tmp` orphans); freed 14G → 27G.

## Provenance

- Jars: `jar=baseline` `jar_sha256=e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b` (60532041 B); `jar=rc2` `jar_sha256=b0ea20484d85e4adce697cb786bf164b6fa4865d9eb122b8c931910e2723e1d6` (60541066 B); both verified 2026-09-24; close-out restored shadow and node jars to baseline `e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b`.
- Config: `test=12` `level_confirmed=12` (config `compression-level: 12` in `paper-world-defaults.yml` + header audit 8383/8383 lvl=12 at offset 17 + 0 `[region-format]` fallback lines); `ldm=0` `flush_threads=1` `compression_workers=0`; staging set `compression-level: 6→12`, `log-flush-batches: false→true`, appended NMT to `sexidium-node.args`; close-out restored `compression-level: 12→6`, `log-flush-batches: true→false`, removed NMT line.
- Conversion: `convert_s=968` (t0 01:03:07Z→t1 01:19:15Z; per-dim walls 879.4+15.5+62.7=957.6s, threads 4/2/2); `mca2linear -c 12` per-dim: OW 7382 files in=23318872064 out=13854576161 ratio=0.594 wall=879.4s; nether 117 files in=274874368 out=134403523 ratio=0.489 wall=15.5s; end 884 files in=2462646272 out=194009210 ratio=0.079 wall=62.7s; all `EXIT=0`, `DONE-ALL`; 0 `.mcc`.
- Verification: header audit 8383/8383 lvl=12 bad=0 (offset 17, `>QBQbhI` field 4); manifest src_sha cross-check 7382+117+884=8383/8383 mism=0 missing=0 extra=0; forceload-subset (16 pristine files) `linear2mca` + `verify` per-dim 12/2/2 files all `total diffs=0`.
- Workload: pristine 16 files (OW 4×(region+entities+poi)=12 + nether 2 + end 2) + `pristine.sha256` 16 lines; `EXPECTED.json` 6144 keys (sha scheme `sha256("dim|cx|cz|mat|level")`) + `commands-y319.txt` 6144 setblocks (4096 OW @319, zero 320) + `commands.txt` copy; forceload query 4096/1024/1024; 21×300 staged EDITs; world region counts OW 2502 / nether 64 / end 676; boot `Done (10.746s)` on smoke, axis boots 10.142, 10.708, 10.304, 10.103.
- Shutdown and safety harness: SIGTERM with 120s grace; `tail-stop.txt` clean checklist (3 markers on baseline); post-shutdown fetch of 6 region files before restart, reboot, per-dim `linear2mca` (errors=0), `chunks-lost-verify.py` (nbtlib, y=319) vs EXPECTED + EDITLOG; sidecars in `samples/12-baseline-1/`, `samples/12-baseline-2/`, `samples/12-baseline-3/`, `samples/12-rc-1/` with EDITLOGs, panels, stats, mem-series, tick-series, verify, tail-stop, runner logs (`l12-b2.runner.log`, `l12-b3.runner.log`, `l12-rc1.runner.log`).
