# folia-linear

Patch supplement that adds the [Linear region format](https://github.com/xymb-endcrystalme/LinearRegionFileFormatTools)
to Folia 26.1.2. Worlds keep using Anvil (`.mca`) until you opt one in; when you
do, its region, POI and entity files are written as `.linear` instead.

![build](https://github.com/Ashu11-A/folia-linear/actions/workflows/build.yml/badge.svg)

- Anvil compresses every chunk on its own with zlib, then pads each one up to a
  4 KiB sector boundary. Both cost space.
- Linear keeps chunks LZ4-compressed in memory and writes the whole region as a
  single zstd blob on save. No per-chunk padding, and zstd sees 1024 chunks of
  similar data at once instead of one.
- Reads always probe both extensions, so a world that already has `.mca` files
  keeps serving them after the flip. Nothing is converted behind your back.
- Architecture follows [Kaiiju](https://github.com/KaiijuMC/Kaiiju), with its
  three known bugs fixed rather than carried over (see
  [docs/architecture.md](docs/architecture.md)).

## Measured results

Stress sweep, full SMP world (~3.05M chunks, 24.99 GiB as Anvil), every level
measured with 3 runs on the pre-fix jar (baseline) and 3 on the fixed jar (rc),
plus SIGKILL durability rows. Raw rows:
`versions/26.1.x/bench/stress-1-22.csv`. Method:
[docs/benchmarks.md](docs/benchmarks.md).

| Level | Size | Saved vs #1 | Shutdown base / rc | Verdict |
|---|---|---|---|---|
| 1 | 16.58 GiB | — (anchor) | 80.0s / 70.4s | ⚠️ works, little margin |
| 3 | 16.04 GiB | 3.30% | 80.3s / 72.5s | ⚠️ works, little margin |
| 6 | 13.87 GiB | 16.37% | 74.4s / 72.3s | ⚠️ works, little margin |
| 9 | 13.45 GiB | 18.86% | 77.2s / 72.4s | ⚠️ works, little margin |
| 12 | 13.21 GiB | 20.33% | 84.3s / **120.9s → SIGKILL, 2047 chunks lost** | base ⚠️ / **rc ❌** |
| 15 | 12.86 GiB | ~22.4% | **121s → SIGKILL** / not run | **base ❌** |

Shutdown is SIGTERM-to-exit against a 120 s grace period. ⚠️ here means the
container peak touched ≥85% of its 6 GiB limit; every graceful shutdown saved
every chunk at levels 1–9 on both jars.

> **Do not use level 12 or above.** At 12 the fixed jar crossed the 120 s grace
> period and was SIGKilled mid-flush, losing 2047 chunks (reproduced 2/2). At 15
> even the pre-fix jar was killed the same way. The durability cliff for the
> fixed jar lies between 9 and 12; for the pre-fix jar, between 12 and 15.

> **Recommended: compression level 6.** Best shutdown numbers of the sweep on
> both jars, 16.37% smaller than level 1 (44.5% smaller than Anvil), and nowhere
> near any cliff.

Durability under SIGKILL (T+30 s, full world, chunks edited then killed): the
pre-fix jar loses ~100% of edited chunks at every level; the fixed jar
(age-based flush + opportunistic flush) loses ~55% with a ~2-minute cutoff.
Ungraceful kills still lose data — Linear is crash-safe, not crash-proof. OOM
kills could not be induced on the test workload, so that row is unmeasured.

Older offline numbers, kept for reference: level 1 converts 24.99 GiB Anvil to
16.57 GiB (33.7% saved); level 22 reaches 11.04 GiB (55.8% vs Anvil). Offline
conversion at 22 runs ~20 files/minute/worker, ~10× slower than level 1.

Suite: 9066 tests green (22 skipped), 70 of them Linear-specific.

## Requirements

- Java 25 for both build and runtime.
- Folia `ver/26.1.x`, pinned in `versions/26.1.x/upstream.properties`
  (Minecraft 26.1.2). CI warns and continues if upstream has moved.
- ~25 GB free disk to build. The build itself is around 10 minutes on CI.

## Build

```bash
# One version:
scripts/build.sh --mc 26.1.x
# All versions:
scripts/build.sh
# -> versions/26.1.x/build/folia-paperclip-26.1.2-*.jar
```

The script clones the pinned Folia ref, stages `versions/<mc>/patches`,
`tests/` and `build-hunk.py`, and runs `applyAllPatches` plus the full build.
`build-hunk.py` splices the test source directory and the zstd-jni dependency
into Folia's own `build.gradle.kts.patch` (paperweight hunk convention); it
aborts instead of guessing if the base file has drifted.

Tagged pushes (`v1.x.y`) build on CI and attach one jar plus its sha256 per
supported version, named `folia-linear-<mc>-<project>.jar`. A manual
`workflow_dispatch` input can limit a release to some versions.

## Configuration

Two settings matter: which format a world writes, and how hard zstd compresses
on flush. Both live under `region-format` in the Paper config files.

`region-format.format` accepts `ANVIL` or `LINEAR` and controls **new writes
only** (reads try both extensions either way). Per world in
`config/worlds/<world>/paper-world.yml`; server-wide default in
`paper-world-defaults.yml`, shipped as `ANVIL`. Flipping back to `ANVIL` is
safe at any time. Unknown values fall back to `ANVIL` with a
`[region-format] Unknown region format` log line.

`region-format.linear.compression-level` is the zstd level on flush, 1–22.
**Default 1; recommended 6; 12 and above are not safe** (see above). Out-of-range
values fall back to 1 with a log line. Changing it is a config flip, not a
migration: the header level byte is informational, decoding is
level-independent, and files are rewritten at the new level as they are saved.

Global knobs in `paper-global.yml` (`flush-frequency` default 10,
`flush-max-threads` default 1, `compression-workers` and
`long-distance-matching` default 0, `log-flush-batches` default false) control
the shared flush pool, the age-based flusher and the zstd workers. `<= 1`
thread keeps the pre-pool serial loop; workers and LDM default to inert.
`crash-on-broken-symlink` (default `true`) halts the server on a broken
`.linear` symlink instead of silently regenerating chunks.

Full reference, including validation order and every log line:
[docs/configuration.md](docs/configuration.md). Ready-to-paste snippets for all
three files are in `release/`.

## Opting a world in

Short version. The full procedure, with the checks that matter, is in
[release/OPERATOR-NOTES.md](release/OPERATOR-NOTES.md).

1. Stop or quiesce the server, snapshot the world's `region/`, `poi/` and
   `entities/`, and write the marker `rollback.sh` requires:
   `date -u +%FT%TZ > /backup/<world>/BACKUP_VERIFIED`.
2. Check for zero-byte `r.*.mca` files and broken symlinks:
   `find <world>/region <world>/poi <world>/entities -xtype l` must come back
   empty.
3. Record a baseline with `du -sb region poi entities` and the `.mca` count.
4. Set `region-format.format: LINEAR` (and `compression-level: 6`) in that one
   world's `paper-world.yml`. Pick a low-traffic world first, never spawn,
   never all worlds at once.
5. Restart, then soak through at least one full save cycle and one more restart.

Signs it is working: new `r.X.Z.linear` files appearing after a save cycle, and
`head -c 8 <file>.linear | od -A x -t x1z` starting with
`c3 ff 13 18 3c ca 9d 9a`.

## Rolling back

`release/rollback.sh` covers three paths. All of them refuse to run without
`--backup-dir` pointing at a snapshot containing a `BACKUP_VERIFIED` marker, and
all support `--dry-run`.

- **Rung A**: flip the world back to `ANVIL` and restart. Dual-read keeps the
  existing `.linear` files readable; new writes are `.mca` again. Proven live.
- **Rung B**: rung A, plus converting `.linear` back to `.mca` and swapping in a
  stock Folia jar. Needed only if you are leaving the fork. You have to supply
  the stock jar path yourself.
- **Rung FORWARD**: re-apply the `LINEAR` opt-in to named worlds.

## Monitoring

- `/linearstats` prints a per-world panel (region/poi/entities): level, time
  since last flush, read/write/flush counts with averages, a dirty-depth bar,
  packed-vs-raw bytes and flush p50/p99, plus a `TOTALS` footer. Permission is
  `linear.command.linearstats`, OP by default.
- `linearstats: no Linear folders tracked (no linear I/O yet).` on an
  Anvil-only node is expected, not an error.
- `LinearRegionFlushCompletedEvent` fires once per flush that touched at least
  one file. It is async by contract; listeners must not touch world state
  directly.

Details in [docs/observability.md](docs/observability.md).

## Compatibility

- Plugin API is untouched. Anything that reads `.mca` bytes directly will not see
  chunks stored in `.linear` files.
- Stock Folia cannot read `.linear`. Leaving the fork means converting back first
  (rung B above).
- Geyser and Bedrock clients are unaffected, since chunk packets are vanilla.
- `.mcc` sidecars for oversized chunks exist on the Anvil side only. The Linear
  writer rejects an oversized payload instead of spilling it to a sidecar.

## Repository layout

- `versions/26.1.x/` - the version-scoped supplement for Folia `ver/26.1.x`
  (pin: `upstream.properties`). A new Minecraft line starts as a copy of the
  previous folder (`scripts/new-version.sh`); porting checklist in
  [CONTRIBUTING.md](CONTRIBUTING.md).
- `versions/26.1.x/patches/` - the fork itself, as paperweight feature patches.
  Core (`minecraft-0009` region format, `0010` crash flags, `0011` recreate
  support, `0012` timing, `0013` unlocked flush, `0014` eviction close,
  `0015` measurement, `0016` shared flush pool, `0017`/`0020` age flush,
  `0018` zstd workers/LDM, `0019` flush bridge) and config/command surface
  (`paper-0008` keys, `0009` constraints, `0010` stats command, `0011` API
  delegate, `0012` knob declarations, `0013` stats panel).
- `versions/26.1.x/tests/` - test sources copied into the fork's test tree.
- `versions/26.1.x/bench/` - the stress harness, the per-run CSV and the
  per-level result docs from the compression sweep.
- `scripts/` - `build.sh`, `new-version.sh`, `preflight.sh` (local mirror of CI).
- `release/` - `rollback.sh`, operator notes, release runbook, config templates.
- `docs/` - architecture, configuration, benchmarks, observability, limitations.
- `.github/workflows/build.yml` - version-matrix build, tests, boot smokes,
  per-version release assets.

## Contributing

CI takes about ten minutes, so run the local mirror before pushing:

```bash
scripts/preflight.sh            # inventory, hunk determinism, workflow checks
scripts/preflight.sh --compile  # + fork compileJava
scripts/preflight.sh --tests    # + Linear suites
```

Push only on green. Patch conventions, the multi-version porting checklist and
the rest of the workflow are in [CONTRIBUTING.md](CONTRIBUTING.md).

## License and credits

GPL-3.0, matching the Paper/Folia/Kaiiju lineage.

- [LinearRegionFileFormatTools](https://github.com/xymb-endcrystalme/LinearRegionFileFormatTools)
  and [LinearPaper](https://github.com/xymb-endcrystalme/LinearPaper) for the
  format and the reference implementation.
- [Kaiiju](https://github.com/KaiijuMC/Kaiiju) for the dual-format architecture.
- [paper-zstd](https://github.com/UltraVanilla/paper-zstd) for the codec
  constraints.
- Spottedleaf's [SectorTool](https://github.com/PaperMC/SectorTool) as spec
  reference, and the GC rules its review established for hot-path buffers.
