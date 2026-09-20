# Changelog

Tags follow the base Minecraft version: `v26.1.2-linear.N`.

## Unreleased

- Release assets renamed from `sexidium-folia-<mcversion>.jar` to
  `folia-<mcversion>-<build>.jar`, where the build number increments for each
  release of the same Minecraft version. The name is derived from the tag, so
  `v26.1.2-linear.3` produces `folia-26.1.2-3.jar`. Assets on the three existing
  releases were renamed to match, which changes their download URLs.
- Documentation rewritten and reorganised by topic. The README now covers the
  region format selector and the zstd compression level, which were previously
  undocumented or buried.
- `docs/` replaced the chronological engineering reports with
  `architecture.md`, `configuration.md`, `benchmarks.md`, `observability.md` and
  `limitations.md`.
- `CONTRIBUTING.md` added; contributor material moved out of the README.
- Corrected in passing: the release runbook pointed at a `templates/` directory
  that does not exist, the README build steps omitted the test-tree `mkdir`, the
  patch inventory omitted `paper-0011`, and the operator notes still described
  the `flush-frequency` boot constraint that `paper-0009` removed.

## v26.1.2-linear.3 - 2026-09-20

- Fixed hunk contexts in `minecraft-0012` and `paper-0010` so
  `applyAllPatches` is clean against the pinned base. The S4 split in `0012`
  and the `PaperCommands` anchor in `paper-0010` were both applying against
  assumed context rather than real context.
- Corrected trailing context and blank-line counts across 14 hunks in
  `minecraft-0012`. `git am` rejects count mismatches that `git apply`
  tolerates, which is what broke CI.

## v26.1.2-linear.2 - 2026-09-20

- Timing instrumentation on the Linear read, write, flush and load paths
  (`minecraft-0012`). Lock-free, `LongAdder` and `LongAccumulator` only, no hot
  interface signature changes, Anvil path byte-identical.
- `/linearstats` command with per-folder and totals rows, plus
  `LinearRegionFlushCompletedEvent` fired async at flush granularity
  (`paper-0010`).
- Paper API delegate `io.papermc.paper.linear.SexidiumLinearStats` so plugins
  can read the counters without NMS imports (`paper-0011`).
- `SexidiumLinearFolderNames` shared helper, pinning `folderType` to `region`,
  `poi` or `entities`.
- Tests: `LinearTimingInstrumentationTest`, `LinearStatsCommandTest`.
- Operator notes gained a section on the readout, the event contract and the
  matching troubleshooting.
- No new config keys. Observability only.

## v26.1.2-linear.1 - 2026-09-19

- `scripts/preflight.sh`, a local mirror of the CI gates. Inventory,
  hunk determinism, patch parsing and workflow self-checks in seconds, with
  optional `--compile` and `--tests` passes.
- CI split into a fast-fail `preflight` job and the full `build` job, so staging
  mistakes stop costing a ten-minute round trip.
- CI builds on `v*` tags and attaches the paperclip jar plus its sha256 to the
  release. `gh release` invocations now carry `--repo` explicitly.

## Earlier, 2026-09-19

Initial publication of the supplement.

- Linear region format ported into Folia 26.1.2 chunk I/O: `LinearRegionFile`
  (v2 writer, v1 and v2 reader), LZ4 hot path, whole-region zstd flush,
  checksums, atomic tmp-force-move saves.
- Dual-read dispatch through `AbstractRegionFile` and
  `AbstractRegionFileFactory`. Reads probe `.mca` first, then `.linear`,
  independently of the configured format.
- `LinearFlushCoordinator`: per-folder bounded dirty set, `MAX_DIRTY = 512`,
  zero threads, eviction on unload.
- Config surface: `region-format.format` (Anvil default), and under
  `region-format.linear`, `compression-level`, `crash-on-broken-symlink`,
  `flush-frequency` and `flush-max-threads`.
- Three Kaiiju defects fixed rather than ported: the `&&` dual-read predicate,
  enum identity in the symlink guard, and the spaceless `(mca|linear)` regex.
- `--forceUpgrade` and `--recreateRegionFiles` honour the world format;
  extension-aware replace with a pre-move flush.
- Release package: `rollback.sh` with rungs A, B and FORWARD behind backup,
  free-space and sha gates; operator notes; config templates.
- Documented live results: 59.6% saved on a 129 MB fixture tree, later
  33.7% across a 24.99 GiB live SMP at level 1, and 55.8% after the level-22
  rewrite.
- CI staging fixes: paperweight hunk handling, git identity before
  `git am`, absolute jar paths in the smoke steps, and generic jar globs.
