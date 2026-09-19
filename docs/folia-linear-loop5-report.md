# Loop 5 Report — harden, rebase drill, packaging, program close-out

## Wave 1: rebase, P1 pair, P2/symlink

- **A1 rebase drill:** upstream STABLE (`ver/26.1.x @62dc0f2`, 0 ahead/behind;
  paperRef/mcVersion unmoved). No rebase needed; all 5 patch files parse;
  runbook written (`/tmp/sexidium-folia/patches/L5-A1/REBASE.md`).
- **A3 P1 (partial):** fixed `PaperWorldAdapter.removeRopeMarkers` (ownsChunk
  pre-check + entity-scheduler routing); module compiles. Flagged the named
  offender `PaperDecorAdapter.sweepStray:332` as still open.
- **A4 P1 tests:** new `SweepStrayRegionDisciplineTest` — 2 red pre-fix
  (pinpointing `sweepStray:332`), 3 green pins.
- **A6 P2 + G12:** P2 = docs fix (serializer ERROR + correct fallback is the
  real behavior; spec SEVERE unreachable dead code — diff prepared). G12:
  vanilla symlink validation intercepts first; format-scoped guard correct;
  matching-extension case inconclusive without players (static 6/6 stands).

## Wave 2: final rebuild + true P1 fix

- **A2 rebuild:** clean `./gradlew build` + `createPaperclipJar` SUCCESS —
  `folia-paperclip-26.1.2.local-SNAPSHOT.jar`, **60,509,601 B**,
  sha256 `3d4713a0…b3cd618c` (byte-identical to Loop-3 build: deterministic).
  Smoke: ANVIL Done 8.4 s; LINEAR Done 5.2 s with **proven read** (fill from
  `.linear`-only chunk, 768 blocks) and **proven write** (`.linear` rewritten);
  rollback reboot Done 5.3 s, 0 errors. 64/64 Linear tests (26/26 coords —
  D1 fully closed).
- **P1b:** fixed `PaperDecorAdapter.sweepStray` (ownsChunk gate + entity
  scheduler routing, no signature changes) — **5/5 green** (2 red→green).

## Wave 3: verify, soak, package, audit

- **A5:** rebuilt plugin (both fixes verified inside jar) booted on fork:
  SX-READY, 18 commands, **0 violations** (was 12). PASS.
- **A7 paired soak:** ANVIL vs LINEAR load walls identical (forceload/summon/
  fill ~0.2–0.4 s both); LINEAR stores **30% of bytes**; single-sample +1.8 s
  shutdown flush noted as noise-to-confirm. p99 honestly UNMEASURED (no players).
- **A8 packaging:** `/tmp/sexidium-folia/release/` (RELEASE.md, rollback.sh
  rungs A/B/FORWARD with backup/free-space/sha gates, OPERATOR-NOTES.md,
  config templates) — all dry-runs PASS.
- **A9 final audit:** CLEAN — far regions 0 diffs, 8/8 rewritten `.linear`
  round-trip parseable, Kaiiju-bug/ANVIL-default gates pass, sexidium drift
  confirmed unrelated (no fork/linear/region files in diff).

## Program verdict: CONDITIONAL-GO (pilot, ANVIL-default)

Cumulative: 59.6% live cut on smp-like data, threading 8/8, rollback proven
live, 9058 fork tests green, plugin clean on fork, deterministic rebuilds.
Conditions: pilot scope only, ANVIL default preserved, backup gate enforced,
players-on p99 tracked post-pilot. Flips to NO-GO on any fork FAIL, failed
live rollback, lost ANVIL default, new threading violation, or skipped backup.
Open, ranked: symlink-live, p99 players-on, dict Phase-2 parked.
Full lucidity in `folia-linear-program-report.md` (companion file).
