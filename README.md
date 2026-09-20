# folia-linear

Patch supplement that adds the [Linear region format](https://github.com/xymb-endcrystalme/LinearRegionFileFormatTools)
to Folia 26.1.2. Worlds keep using Anvil (`.mca`) until you opt one in; when you
do, its region, POI and entity files are written as `.linear` instead, which on
real world data is roughly half the disk.

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

- Fixture tree, 129 MB of SMP-like data: **128,961,741 B to 52,163,783 B, 59.6%
  saved**, 0 chunk diffs over ~39k audited chunks.
- Live SMP, ~3.05M chunks, converted at compression level 1:
  **24.99 GiB to 16.57 GiB, 33.7% saved**.
- Same tree rewritten at level 22: **16.57 GiB to 11.04 GiB**, which is
  **55.8% against the original Anvil size**.
- Boot and save walls are unchanged against Anvil on the same fixtures. Tick p99
  with players on has not been measured yet; see
  [docs/limitations.md](docs/limitations.md).
- 9058 tests green on the patched fork, 64 of them Linear-specific.

Per-dimension tables and the method behind each number are in
[docs/benchmarks.md](docs/benchmarks.md).

## Requirements

- Java 25 for both build and runtime.
- Folia `ver/26.1.x`, pinned at `62dc0f257a4f5de1ef2eae8cf1627156a769c67f`
  (Minecraft 26.1.2). CI warns and continues if upstream has moved.
- ~25 GB free disk to build. The build itself is around 10 minutes on CI.

## Build

```bash
# 1. Pinned base
git clone --branch ver/26.1.x --single-branch https://github.com/PaperMC/Folia.git folia

# 2. Stage this supplement into it
cp folia-linear/patches/minecraft-*.patch folia/folia-server/minecraft-patches/features/
cp folia-linear/patches/paper-*.patch     folia/folia-server/paper-patches/features/
mkdir -p folia/folia-server/src/test/java/net/sexidium
cp folia-linear/tests/*.java folia/folia-server/src/test/java/net/sexidium/
python3 folia-linear/scripts/apply-deps-hunk.py folia/folia-server/build.gradle.kts.patch

# 3. Build
cd folia
./gradlew applyAllPatches build folia-server:createPaperclipJar
# -> folia-server/build/libs/folia-paperclip-26.1.2-*.jar
```

`apply-deps-hunk.py` splices the test source directory and the zstd-jni
dependency into Folia's own `build.gradle.kts.patch`. That file uses the
paperweight hunk convention, which plain `git apply` cannot parse, hence the
script. It aborts instead of guessing if the base file has drifted.

Tagged pushes (`v*`) build on CI and attach the release asset plus its sha256.
Assets are named `folia-<mcversion>-<build>.jar`, where the build number
increments for each release of the same Minecraft version, so the tag
`v26.1.2-linear.3` produces `folia-26.1.2-3.jar`.

## Configuration

Two settings matter in practice: which format a world writes, and how hard zstd
compresses on flush. Both live under `region-format` in the Paper config files.

### Choosing the format

`region-format.format` accepts `ANVIL` or `LINEAR`. It controls **new writes
only**; reads try both extensions either way.

- Per world, in `config/worlds/<world>/paper-world.yml`:

  ```yaml
  region-format:
    format: LINEAR
  ```

- Server-wide default, in `paper-world-defaults.yml`:

  ```yaml
  region-format:
    format: ANVIL
  ```

- The shipped default is `ANVIL` everywhere. Nothing changes until you set a
  world to `LINEAR` and restart.
- A mix of `ANVIL` and `LINEAR` worlds in one process is a supported end state,
  not a degraded one. The switch is per storage folder, so `region/`, `poi/` and
  `entities/` of the same world all follow that world's setting.
- Unrecognised values (including lowercase `linear`) log
  `[region-format] Unknown region format, expected ANVIL or LINEAR. Falling back to ANVIL.`
  and the world runs on Anvil. Check for that line after any config edit.
- Flipping a world back to `ANVIL` is safe at any time. Existing `.linear` files
  stay readable through dual-read; only new writes go back to `.mca`.

### Compression level

`region-format.linear.compression-level` is the zstd level used when a region is
flushed to disk. Range 1 to 22, default 1.

```yaml
region-format:
  format: LINEAR
  linear:
    compression-level: 1
```

- It is a per-world key, so it goes in the same file as `format`
  (`paper-world.yml`, or `paper-world-defaults.yml` for the default).
- It only affects the zstd flush. Chunks staged in memory are always LZ4 at a
  fixed setting, so the level never touches the tick-adjacent write path.
- Out-of-range values log
  `[region-format] linear.compression-level must be 1-22, got <v>. Falling back to 1.`
  and run at 1. The value is clamped again in `AbstractRegionFileFactory` and
  once more in the `LinearRegionFile` constructor, so a bad value cannot reach
  the codec.
- Changing the level is a config flip, not a migration. The level byte in the
  file header is informational and decoding does not depend on it, so old files
  stay readable and get rewritten at the new level as they are saved.

What the level buys, measured offline on the live SMP tree (region files only):

| Dimension | Level 1 | Level 22 | Saved |
|---|---|---|---|
| Overworld | 17,339,006,898 B | 11,561,937,798 B | 33.3% |
| Nether | 165,375,247 B | 111,835,003 B | 32.4% |
| End | 291,280,114 B | 157,860,846 B | 45.8% |
| Total | 16.57 GiB | 11.04 GiB | 33.4% |

Before raising it:

- Offline conversion at 22 ran about 20 files per minute per worker, roughly ten
  times slower than at 1. Each overworld half took ~40 minutes across 8-10
  workers.
- The cost of level 22 on the *live* flush path has not been measured over a
  long soak. Two clean boots and a `save-all` at 22 were fine, but that is not a
  soak.
- Run a new world at level 1 through at least one full save cycle and one
  restart first. Raise it after that, not before.

### Remaining keys

| Key | File | Default | Effect |
|---|---|---|---|
| `region-format.format` | `paper-world.yml`, `paper-world-defaults.yml` | `ANVIL` | Format for new writes. Unknown value falls back to `ANVIL`. |
| `region-format.linear.compression-level` | same | `1` | zstd level on flush, 1-22. Out of range falls back to `1`. |
| `region-format.linear.crash-on-broken-symlink` | same | `true` | Halts the server when a `.linear` path is a broken symlink. |
| `region-format.linear.flush-frequency` | `paper-global.yml` | `10` | Declared, validated, **read by nothing in this release**. |
| `region-format.linear.flush-max-threads` | `paper-global.yml` | `1` | Declared, validated, **read by nothing in this release**. |

- `crash-on-broken-symlink` halts on purpose: a broken symlink usually means a
  mounted volume disappeared, and continuing would silently regenerate chunks.
  Resolve symlinks before opting a world in. Setting it to `false` turns the halt
  into a warning, which is a forensics mode, not a normal setting.
- The two flush knobs exist because the config surface mirrors Kaiiju's. There is
  no flush scheduler or thread pool wired to them yet, so tuning them does
  nothing. They are still validated: `flush-frequency < 1` logs
  `[region-format] linear.flush-frequency must be >= 1, got <v>. Falling back to 10.`
- Ready-to-paste snippets for all three files are in `release/`:
  `paper-world-defaults.region-format.yml`, `paper-world.region-format.yml`,
  `paper-global.region-format.yml`.

Full reference, including validation order and every log line:
[docs/configuration.md](docs/configuration.md).

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
4. Set `region-format.format: LINEAR` in that one world's `paper-world.yml`.
   Pick a low-traffic world first, never spawn, never all worlds at once.
5. Restart, then soak through at least one full save cycle and one more restart.
   Linear buffers flush on save, and the second restart proves the files reopen.

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

- `/linearstats` prints per-folder read, write, flush and load counts with
  average microseconds, plus a `TOTALS` row. Permission is
  `sexidium.command.linearstats`, OP by default.
- `linearstats: no Linear folders tracked (no linear I/O yet).` on an
  Anvil-only node is expected, not an error.
- `LinearRegionFlushCompletedEvent` fires once per flush that touched at least
  one file. It is async by contract; listeners must not touch world state
  directly.
- Counters and the event are read-only instrumentation. They add no config keys
  and change no behaviour.

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

- `patches/` - the fork itself, as paperweight feature patches.
  - `minecraft-0009` Linear core, dual-read dispatch, broken-symlink guard.
  - `minecraft-0010` crash-flag wiring and guard call sites.
  - `minecraft-0011` recreate-format support, flush policy, factory mapping,
    oversized guard.
  - `minecraft-0012` timing counters on the Linear read, write, flush and load
    paths.
  - `paper-0008` config keys and dual-read tests.
  - `paper-0009` flush-frequency constraint removal and upgrade path.
  - `paper-0010` `/linearstats` command, flush event, folder-name helper.
  - `paper-0011` Paper API delegate so plugins can read stats without NMS
    imports.
- `tests/` - test sources copied into the fork's test tree: Linear round-trip,
  timing instrumentation, `/linearstats` behaviour, and the suite class that
  makes the fork's Gradle task actually run them.
- `scripts/` - `preflight.sh` (local mirror of CI) and `apply-deps-hunk.py`.
- `release/` - `rollback.sh`, operator notes, release runbook, config templates.
- `docs/` - architecture, configuration, benchmarks, observability, limitations.
- `.github/workflows/build.yml` - preflight gate, then full build, tests, boot
  smokes and release asset.

## Contributing

CI takes about ten minutes, so run the local mirror before pushing:

```bash
scripts/preflight.sh            # inventory, hunk determinism, workflow checks
scripts/preflight.sh --compile  # + fork compileJava
scripts/preflight.sh --tests    # + Linear suites
```

Push only on green. Patch conventions and the rest of the workflow are in
[CONTRIBUTING.md](CONTRIBUTING.md).

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
