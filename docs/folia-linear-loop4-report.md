# Loop 4 Report — live validation on the fork jar

Jar under test: `folia-paperclip-26.1.2.local-SNAPSHOT.jar` (60.5 MB).
Scratch-only boots; live server never touched.

## Gate results (20 gates)

| Gate | Result | Evidence |
|---|---|---|
| G1 boot matrix (ANVIL/mixed/LINEAR) | PASS | Done 7.4/6.6/5.2/6.8/5.1 s, zero fork errors |
| G2 legacy-migration crash | PASS (upstream, workaround documented) | remove superseded legacy dirs |
| G3 3-cycle soak, no drift | PASS | Done ~5 s, saves same-second, 25/25 sha identical, opacity PASS x3 |
| G4 threading NO-GOs | PASS 8/8 | no global flusher, no thread-per-file, Moonrise IO only |
| G5 LINEAR writes happen | PASS (proven) | 4x `.linear`, magic `c3ff1318`, deferred-flush observed |
| G6 live cut ≥50% | PASS, beats target | 128,961,741 → 52,163,783 B = **0.404, 59.6% saved** |
| G7 boot delta | PASS (noise, -0.1 s) | — |
| G8 save parity | PASS | same-second both formats |
| G9 tick p99 | UNMEASURED (no players; methodology deferred) | — |
| G10 unknown format | PASS with doc deviation | ERROR + fallback + boot (spec SEVERE string differs — P2) |
| G11 level clamp | PASS | 0/100 → SEVERE + fallback 1 |
| G12 symlink live | UNTESTED (static coverage stands) | — |
| G13 rollback Rung A live | PASS | LINEAR→ANVIL reboot serves `.mca`, 0 errors |
| G14 entities/POI LINEAR | PASS | `.linear` re-saved across boots, 0 errors |
| G15 probe order | PASS (expected `.mca` preference) | — |
| G16 linear2mca | PASS | 74 files, 0 errors |
| G17 network | PASS | status JSON, 44 ms / 0.7 ms pong, protocol 775 |
| G18 audit | PASS with caveat | 25 `.mca` + 13 `.linear`, ~39k chunks, 0 fail |
| G19 plugin compat | CONDITIONAL PASS | plugin builds + enables (SX-READY, 18 cmds) BUT 3x pre-existing Folia violation in `PaperDecorAdapter.sweepStray:332` (stock-Folia reproducible, not fork-caused) → P1 |
| G20 LINEAR I/O unwitnessed (B1) | CLOSED by B3 | — |

Tally: 17 PASS, 2 UNMEASURED, 0 FAIL vs the fork.

## Defects for Loop 5

- **P1** (code): `PaperDecorAdapter.sweepStray:332` sync `getChunkAt` off region
  thread — fix in sexidium repo via region-scheduler discipline + regression test.
- **P2** (doc/code): FOO log-string deviation — cheapest fix wins.
- **P3** (measurement): players-on p99 methodology + paired runs.
- **P4** (process): rebase drill, final jar, packaging runbook, program report.

## Process lesson

Blanket `pkill -9 java` by sibling agents killed several boots mid-window.
Loop 5 rule: unique process markers (pidfiles, distinct ports/workdirs), never
blanket kills. None of the kills were fork crashes.
