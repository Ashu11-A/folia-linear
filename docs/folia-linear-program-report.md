# Program Report — Sexidium-Folia: Folia 26.1.2 Fork with Native Linear Region Compression

**Status: CONDITIONAL-GO** (pilot-ready, ANVIL-default). 5 loops, 48 agents,
0 FAIL vs fork. Companion per-loop reports: `local-compress-loop2/3-report.md`
(cold tiers, prior program), `folia-linear-loop{2,3,4,5}-report.md` (this program).

## Per-loop record

| Loop | Scope | Outcome |
|---|---|---|
| 1 — Research (10 agents) | All link contents (LinearPaper/Kaiiju/SectorTool/paper-zstd/threads/Folia build/vanilla codecs/tools) + infra clones | Format=Linear; inventory + build recipe + 8-risk register |
| 2 — Port (10) | Parity build, Linear core, factory/dual-read, config, codec, bugfixes, converter, harness | Bootable jar; 64-test base; flush-affinity contract |
| 3 — Integrate (10) | Clean-apply fixes, upgrade/recreate, flusher policy, mapping, revert-proof, K4, test wiring | 60,509,601 B jar; 9058 tests green |
| 4 — Validate (10) | 20 live gates: boots, soak, threading, perf, config, entities, ping, audit, plugin | 17 PASS / 2 UNMEASURED / 0 FAIL; 59.6% cut |
| 5 — Harden+release (10) | Rebase drill, P1 fix+verify, paired soak, packaging, final audit | Deterministic rebuild; P1 12→0 violations; release package |

## Key numbers

- Live disk: 128,961,741 → 52,163,783 B (**0.404, 59.6% saved**); soak world 30%.
- Tests: 9058 fork green (64 Linear); SweepStray 5/5 red→green; suites 1492 (plugin) green.
- Boot: Done 5–8 s all modes; saves same-second; ping 44 ms / 0.7 ms.
- Jar: `folia-server/build/libs/folia-paperclip-26.1.2.local-SNAPSHOT.jar`,
  sha256 `3d4713a0c78a68d01f33cc9f44685cdfbbcd1b508cb1033cd4366f62b3cd618c`
  (byte-identical across rebuilds).
- Release: `/tmp/sexidium-folia/release/` (RELEASE.md, rollback.sh A/B/FORWARD,
  OPERATOR-NOTES.md, templates) — dry-runs PASS.

## Go conditions (all four)

1. Pilot scope only. 2. ANVIL default preserved. 3. Backup gate enforced.
4. Players-on p99 tracked post-pilot. NO-GO triggers: any fork FAIL, failed
live rollback, lost ANVIL default, new threading violation, skipped backup.

## Maintenance contract

Rebase per upstream release (runbook filed; STABLE at program end). Breakage
surface: LinearPaper/Kaiiju hunks, Moonrise/SimpleRegionStorage/Upgrader drift,
forceWrite paths, MAX_DIRTY, factory mapping, zstd-jni. Owners: fork maintainer
(patches/jar), operator (config/backups/rollback), plugin maintainer
(region discipline). Open, ranked: symlink-live test, p99 players-on,
dict Phase-2 parked, per-node-disk N/A.
