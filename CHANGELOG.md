# Changelog

Tags are project versions (`v1.x.y`). Each release attaches one jar + `.sha256`
per supported version line, named `folia-linear-<mcversion>-<project>.jar`.

## v1.3.0 - 2026-09-26

Async periodic flush drain (tick thread never blocks on file rewrites) and
the shipped compression default drops from 9 to 6. Decided by a 9-run flush
battery (gate vs async vs v1.2.0 baseline, 60 virtual players, 6 tick
regions): async cut tick stalls 42→2 with zero flush-path stalls, while the
gate alternative regressed. Full study: `docs/flush-battery.md`.

- **Async drain:** periodic drains (`processUnloads`, autosave) submit to the
  shared flush pool and return without joining; forced and stop drains
  (`evictAll`, `flushAllDirty(true)`) keep the synchronous barrier and join
  in-flight batches. Approved trade-off: a crash may lose up to one
  `flush-frequency` window of writes; clean shutdown stays zero-loss.
- **Default level 6:** `DEFAULT_COMPRESSION_LEVEL`, the config default and
  the out-of-range fallback all move 9 → 6 (sweep: 42.9% smaller than Anvil,
  tightest shutdown range). v1.2.0 entries below describe what shipped then;
  they are historical and unchanged.
- **Battery:** gate rejected (stalls 34/32/50, worst single run overall);
  baseline control (42/36/26); async (2/2/2, all non-flush). Crash restarts
  clean on all three; late-run TPS decay is generation-bound on every jar.

## v1.2.0 - 2026-09-26

Patch consolidation, Linear-by-default, automatic startup conversion with a
validated pipeline, and save-path durability wiring. Built from
`versions/26.1.x` at Folia `62dc0f2` (MC 26.1.2), Java 25.

- **Patch modules:** the 18 v1.1.0 patches are consolidated into 13 numbered
  modules (`versions/26.1.x/patches/MODULES.md` maps old→new). Kept text is
  v1.1.0 tip behavior; known deltas are the API fields and the new
  conversion/drain modules below.
- **Defaults flip:** new worlds default to `region-format.format: LINEAR`
  with `linear.compression-level: 9` (was ANVIL / 1). Worlds with an
  explicit `format: ANVIL` keep working untouched (dual-read, ANVIL
  fail-safes, and the `null → ANVIL` fallback are all preserved and tested).
- **Startup auto-conversion:** on boot, before any plugin code runs, worlds
  whose active format resolves to LINEAR convert leftover `.mca` files to
  level-9 `.linear`. Explicit-ANVIL worlds never convert.
- **Conversion pipeline:** per-file CONVERT → VALIDATE → DELETE stages run
  in parallel across files on a bounded pool; per-file order is strict (never
  delete unvalidated). Validation requires target existence, header sanity,
  chunk-count parity, and full payload decompression. Failures re-queue up
  to 3 attempts; exhaustion enters protection mode (descriptive terminal
  alert) and halts the server for inspection. Valid shadows and divergent
  pairs escalate, never auto-delete; crash orphans (`new_*` dirs) are
  cleaned on the next run.
- **Save-drain wiring:** the coordinator dirty set previously drained only
  via bound pressure, so fresh worlds persisted nothing on clean stop.
  Unload passes (`ChunkMap.processUnloads`), explicit saves and shutdown
  (`RegionShutdownThread` post-`stopServer`) now drain via
  `flushAllDirty`/`evictAll`. Proven live: dirty files at stop persist as
  `.linear`.
- **`LinearStats` API:** `FolderSnapshot` gains `rawBytes`,
  `compressedBytes`, `flushP50Micros`, `flushP99Micros`,
  `millisSinceLastFlush` (already shown by `/linearstats`).
- **Config:** the three `release/paper-*.region-format.yml` snippets are
  replaced by one comment-free `release/region-format.yml` (`global:`,
  `world-defaults:`, `per-world-example:` sections); explanations moved to
  `docs/configuration.md`. Per-world file lives at
  `<world>/dimensions/minecraft/<dimension>/paper-world.yml`.
- **License:** `LICENSE` (GPL-3.0-only) added, matching the README claim.
- **CI:** workflows split into `build.yml` (tags/releases/dispatch, paperclip +
  release assets) and `test.yml` (every push/PR: static gates, preflight, unit
  suites, config checks).
- **Upgrading:** pin `format: ANVIL` on worlds you do NOT want converted
  before first boot, or they convert automatically. Downgrade after
  converting is one-way until re-conversion completes (do not run an older
  jar on converted worlds and expect the new files to be picked up).

## v1.1.0 - 2026-09-25

Performance and observability update. Anvil remains the default; Linear is
opt-in per world with dual-read from first boot. Drop-in replacement over
v1.0.0, no world conversion required, one deliberate behaviour change (flush
victim ordering, below).

- Shared bounded flush pool behind `flush-max-threads` with caller-participates
  durability barrier; serial path stays byte-identical when `<= 1`. Flush writes
  direct-into-image, removing one full region copy.
- Real age-based flush behind `flush-frequency` (first-dirty age,
  longest-unflushed first; eviction forces, bound pressure ignores age) plus
  opportunistic drain on `markDirty` (one age-eligible file per call,
  production frequencies only).
- zstd writer `setWorkers` / `setLong` and reader `setLongMax(27)` tuning
  (defaults `0`, reader-first).
- `/linearstats` Adventure panel (per-world region/poi/entities, human units,
  dirty bar, level + millis-since, TOTALS) with `LinearRegionFlushCompletedEvent`
  bridge call site and `LinearStats` Paper API delegate for plugins.
- Fixed: `/linearstats` level column showed `?` for all worlds (dimension id vs
  level-name lookup); now resolves via direct name then dimension identifier
  match, never throws.
- Fixed: dirty files could stay pending without a manual `save-all flush` or
  stop (autosave and plain `save-all` never reach the flush path); workloads now
  self-drain within ~`flush-frequency`. Plain `save-all` without `flush` stays a
  no-op by design.
- Breaking: flush-victim ordering changed (least-recently-written →
  longest-unflushed). `/linearstats` permission is now
  `linear.command.linearstats`. Config defaults unchanged (`format: ANVIL`,
  `compression-level: 1`).

## v1.1.0-rc2 - 2026-09-22

Preview. Fixes over rc: level-column lookup (above), opportunistic age flush
(`LinearAgeBasedFlushTest`, 5/5), and one item left unchanged by design (no JVM
flag hook in the container entrypoint). Full suite green, Linear suites 37/37.

## v1.1.0-rc - 2026-09-21

Preview of the v1.1.0 performance and observability update (shared pool,
age-based flush, zstd tuning, `/linearstats` panel + bridge call site).
`LinearNmsTestSuite` 70/70.

## v1.0.0 - 2026-09-25

Restructured baseline with no behaviour change: `versions/26.1.x/` layout,
`net.linear` namespace, CI matrix and scripts. Byte-identity is not expected
because the rename changed class names. Full suite green (folia-server 9042
tests, 0 failures, 22 skipped); Linear filter 48/48; preflight 33/33.

Earlier history, folded in:

- Linear region format ported into Folia chunk I/O: `LinearRegionFile`
  (v2 writer, v1/v2 reader), LZ4 hot path, whole-region zstd flush, checksums,
  atomic tmp-force-move saves.
- Dual-read dispatch: reads probe `.mca` first, then `.linear`, independently
  of the configured format.
- `LinearFlushCoordinator`: per-folder bounded dirty set, `MAX_DIRTY = 512`,
  eviction on unload.
- Config surface: `region-format.format` (Anvil default), `compression-level`,
  `crash-on-broken-symlink`, `flush-frequency`, `flush-max-threads`.
- Three Kaiiju defects fixed rather than ported: the `||` dual-read predicate,
  enum identity in the symlink guard, and the spaceless `(mca|linear)` regex
  (grep-gated against reintroduction).
- Lock-free timing instrumentation (`LongAdder`/`LongAccumulator` only, Anvil
  path byte-identical); `/linearstats` command; `LinearStats` Paper API
  delegate; `LinearFolderNames` helper.
- `--forceUpgrade` and `--recreateRegionFiles` honour the world format.
- `scripts/preflight.sh` local CI mirror; CI builds on `v*` tags and attaches
  the paperclip jar plus its sha256.
- Release package: `rollback.sh` with rungs A, B and FORWARD behind backup,
  free-space and sha gates; operator notes; config templates.
