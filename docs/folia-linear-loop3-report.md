# Loop 3 Report — converters, upgrade, flusher, happy-path tests

## Applied (fork checkout `/tmp/sexidium-folia/folia`)

- L3-B1 clean-apply fixes: Loop-2 patches failed `git am` as-is (3 failures:
  stale build-hunk offsets, 11 hunkless new-file sections written empty, wrong
  counts git-apply tolerates but `git am` rejects, B2 guard commit silently
  dropped). Fixed set verified: clean `applyAllPatches` PASS + compile + full
  build PASS. Canonical patches re-serialized (`0008/0009/0010`).
- L3-B2: `--recreate` upgrader honors world format (new `RecreatingSimpleRegionStorage`
  9-arg overload, extension-aware replace, pre-move flush); `--forceWrite`
  equivalence documented (FORCEWRITE.md).
- L3-B3: coordinator-aware batching in `MoonriseRegionFileIO` (Anvil keeps
  per-write flush; Linear defers to marks); MAX_DIRTY=512 kept (2× the 256 cache);
  flush-frequency/threads stay inert/reserved; unload eviction retained.
- L3-B4: `fromConfig()` single mapping point (both call sites rerouted);
  oversized guard (500 MiB parity, refuse-by-delete, Anvil `.mcc` untouched).
- L3-B5: upgrade-rewrite entry un-stubbed (`forceUpgrade`/`--recreateRegionFiles`
  reachable); full REVERT-PROOF.md (container convert → forced rewrite → stock
  readable) + `verify_revert.py`.
- K4 fixed: `@Constraints.Min(1)` removed from `flushFrequency` (PostProcess
  SEVERE+10 fallback, K2 pattern).
- Test execution wired: new `SexidiumNmsTestSuite` (upstream task only ran
  `**TestSuite` classes, so NMS tests never executed).

## Test information

| Suite | Result |
|---|---|
| Fork `./gradlew build` + `createPaperclipJar` | SUCCESS — `folia-paperclip-26.1.2.local-SNAPSHOT.jar` (**60,509,601 B**), `--help` bootstraps, `--forceUpgrade`/`--recreateRegionFiles` listed |
| UpgraderScan / BrokenSymlinkGuard / Coordinates / LinearRoundTrip | 29 + 6 + 26 + 3 = **64/64 green** (incl. 10 formerly-failing bootstrap cases) |
| Full fork default suite | **9058 tests, 0 failures**, 22 skipped |
| T2 dual fixtures + opacity | non-strict PASS, strict correctly FAILs (12 PENDING-MCA) |
| T2 rollback RUNG-B (linear2mca, offline) | 0 diffs, ~1 s |
| T3 audits (Kaiiju bugs / ANVIL default / opacity / repo untouched) | all PASS |
| T4 config matrix | all keys match; K4 fixed; B4 single-point confirmed |

## Deferred to Loop 4

Live boot matrix (SOAK-PLAN S1–S8), runtime config flips, live rollback Rung A,
L3-B2 open Q1–Q6, hot-write p99 + live-bytes numbers (never cold-2x gates).

## Loop 4 input

Boot the §3 jar on scratch fixtures: mixed + LINEAR worlds, save/restart cycles,
threading-log audit vs A2 contract, vanilla ping/join probe, Sexidium plugin
compat load, post-soak chunk audits, then program close-out in Loop 5.
