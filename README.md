# folia-linear

Patch supplement that adds the [Linear region format](https://github.com/xymb-endcrystalme/LinearRegionFileFormatTools)
to Folia 26.1.2. Worlds write Linear (`.linear`) region, POI and entity files
by default; any world can be pinned back to Anvil (`.mca`) per world.

![test](https://github.com/Ashu11-A/folia-linear/actions/workflows/test.yml/badge.svg)
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

Stress sweep, full SMP world (24.27 GiB as Anvil per the sweep CSV constant),
3 runs per level on the fixed jar (rc), plus SIGKILL durability rows. Raw rows:
`versions/26.1.x/bench/stress-1-22.csv`. Method:
[docs/benchmarks.md](docs/benchmarks.md).

| Level | Size | Saved vs Anvil | Shutdown (grace 120 s) | Chunks lost |
|---|---|---|---|---|
| Anvil | 24.27 GiB | — (anchor) | — | — |
| 1 | 16.58 GiB | 31.7% | 70–75 s | 0 |
| 3 | 16.03 GiB | 33.9% | 66–84 s | 0 |
| 6 | 13.86 GiB | 42.9% | 71–74 s | 0 |
| 9 | 13.45 GiB | 44.6% | 69–74 s | 0 |
| 12 | 13.21 GiB | 45.6% | 120.9 s → SIGKILL | 2047 of 6144 |
| 15 † | 12.86 GiB | 47.0% | 121.0 s → SIGKILL | unknown |
| 22 †† | 11.04 GiB | ~54.5% | — | — |

Shutdown is SIGTERM-to-exit against a 120 s grace period. Levels 1–9 shut down
gracefully on all 12 rc runs with zero chunks lost.

- † Level 15 ran on the pre-fix jar only; chunks-lost is unknown (the driver
  died before verify completed).
- †† Level 22 comes from the offline level-1-vs-22 rewrite, not the stress
  sweep: no shutdown coverage, savings approximate.
- Memory: 6 GiB container; cgroup peak touched the ceiling on every run, heap peak ≤3.0 GiB, 0 OOM kills. Tick p99 unmeasured on all runs.

> **Do not use level 12 or above.** At 12 the fixed jar crossed the 120 s grace
> period and was SIGKilled mid-flush, losing 2047 chunks. The durability cliff
> for the fixed jar lies between 9 and 12.

> **Recommended: compression level 6.** Tightest shutdown range of the sweep,
> 42.9% smaller than Anvil, and nowhere near any cliff. Level 9 is the shipped
> default.

Durability under SIGKILL (T+30 s, full world, chunks edited then killed): the
fixed jar loses ~55% of edited chunks (3267–3486 of 6144 across 4 runs).
Ungraceful kills still lose data — Linear is crash-safe, not crash-proof. OOM
kills could not be induced on the test workload, so that row is unmeasured.

Offline conversion at 22 runs ~20 files/minute/worker, ~10× slower than
level 1. Full-tree numbers (24.99 GiB anchor) are in
[docs/benchmarks.md](docs/benchmarks.md).

Suite: `LinearNmsTestSuite` 79 tests green (incl. 17 conversion-pipeline, 10
startup-conversion, 10 default-format, 3 save-drain).

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
`build-hunk.py` (in `versions/<line>/`) splices the test source directory and the zstd-jni dependency
into Folia's own `build.gradle.kts.patch` (paperweight hunk convention); it
aborts instead of guessing if the base file has drifted.

Tagged pushes (`v*`) build on CI and attach one jar plus its sha256 per
supported version, named `folia-linear-<mc>-<project>.jar`. A manual
`workflow_dispatch` input can limit a release to some versions.

## Configuration

Two settings matter: which format a world writes, and how hard zstd compresses
on flush. Both live under `region-format` in the Paper config files.

`region-format.format` accepts `ANVIL` or `LINEAR` and controls **new writes
only** (reads try both extensions either way). Per world in
`<world>/dimensions/minecraft/<dimension>/paper-world.yml`; server-wide default in
`paper-world-defaults.yml`, shipped as `LINEAR`. Pinning a world back to
`ANVIL` is safe at any time. Unknown values fall back to `ANVIL` with a
`[region-format] Unknown region format` log line.

`region-format.linear.compression-level` is the zstd level on flush, 1–22.
**Default 9; recommended 6; 12 and above are not safe** (see above). Out-of-range
values fall back to 9 with a log line. Changing it is a config flip, not a
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
[docs/configuration.md](docs/configuration.md). A ready-to-paste,
comment-free snippet covering all three blocks is in
`release/region-format.yml`.

## Opting a world out (LINEAR is the default)

Short version. The full procedure, with the checks that matter, is in
[release/OPERATOR-NOTES.md](release/OPERATOR-NOTES.md).

1. Stop or quiesce the server, snapshot the world's `region/`, `poi/` and
   `entities/`, and write the marker `rollback.sh` requires:
   `date -u +%FT%TZ > /backup/<world>/BACKUP_VERIFIED`.
2. Check for zero-byte `r.*.mca` files and broken symlinks:
   `find <world>/region <world>/poi <world>/entities -xtype l` must come back
   empty.
3. Record a baseline with `du -sb region poi entities` and the `.mca` count.
4. To pin a world back to Anvil, set `region-format.format: ANVIL` in that one
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
  Core (`minecraft-0009` region format incl. crash flags + recreate support,
  `0010` observability incl. measurement, `0011` unlocked flush incl. eviction
  close, `0012` flush coordinator incl. shared pool + age flush + bridge,
  `0013` zstd workers/LDM tuning) and config/command surface (`paper-0008`
  config blocks + clamps, `paper-0009` linearstats incl.
  API delegate + stats panel). Module map: `patches/MODULES.md`.
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

Full text: [LICENSE](LICENSE).

- [LinearRegionFileFormatTools](https://github.com/xymb-endcrystalme/LinearRegionFileFormatTools)
  and [LinearPaper](https://github.com/xymb-endcrystalme/LinearPaper) for the
  format and the reference implementation.
- [Kaiiju](https://github.com/KaiijuMC/Kaiiju) for the dual-format architecture.
- [paper-zstd](https://github.com/UltraVanilla/paper-zstd) for the codec
  constraints.
- Spottedleaf's [SectorTool](https://github.com/PaperMC/SectorTool) as spec
  reference, and the GC rules its review established for hot-path buffers.
