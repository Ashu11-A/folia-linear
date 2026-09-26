# Configuration reference

Every setting the Linear patches add lives under a `region-format` block. Three
sit in the world config, five in the global config. The README covers the
two you will actually tune. Full surface below, including what the
server does with a bad value.

## Key map

| Key | Config file | Scope | Type | Default |
|---|---|---|---|---|
| `region-format.format` | `paper-world.yml`, `paper-world-defaults.yml` | per world | `ANVIL` / `LINEAR` | `LINEAR` |
| `region-format.linear.compression-level` | same | per world | int 1-22 | `9` |
| `region-format.linear.crash-on-broken-symlink` | same | per world | bool | `true` |
| `region-format.linear.flush-frequency` | `paper-global.yml` | server | int >= 1 | `10` |
| `region-format.linear.flush-max-threads` | `paper-global.yml` | server | int | `1` |
| `region-format.linear.compression-workers` | `paper-global.yml` | server | int >= 0 | `0` |
| `region-format.linear.long-distance-matching` | `paper-global.yml` | server | int >= 0 | `0` |
| `region-format.linear.log-flush-batches` | `paper-global.yml` | server | bool | `false` |

The world keys are defined in `WorldConfiguration`, the global ones in
`GlobalConfiguration`, both in `patches/paper-0008-*.patch`. All but
`log-flush-batches` are wired at their defaults (see below).

## Placement

- `paper-world-defaults.yml` holds the fallback for every world. The block goes
  at the top level, not under `chunks`. The shipped default is `LINEAR`; pin a
  single world back to `ANVIL` with an explicit per-world `format: ANVIL`.
- `<world>/dimensions/minecraft/<dimension>/paper-world.yml` overrides it for one world. Leave the
  file without a `region-format` block and the world inherits the default.
- `paper-global.yml` holds the global flush keys, also at the top level.
- Restart after editing. None of these keys are re-read at runtime.

Template you can paste directly (comment-free; one file holds the
`paper-world-defaults.yml`, per-world `paper-world.yml` and `paper-global.yml`
blocks — copy each block into its target file at the top level):

- `release/region-format.yml`

## `format`

```yaml
region-format:
  format: LINEAR
```

- Shipped default is `LINEAR` for every world (see `release/region-format.yml`).
  An explicit per-world `format: ANVIL` opts a world back out; mixed `ANVIL`
  and `LINEAR` worlds in one process is the supported end state, not a
  degraded one.
- Chooses the extension used for **new writes**. Reads probe `.mca` first, then
  `.linear`, regardless of this setting, which is why flipping it never hides
  existing data.
- Resolved through the `RegionFileFormat` enum. Unknown strings deserialise to
  `null`, and a `@PostProcess` step logs the fallback and substitutes `ANVIL`.
  The comparison is case-sensitive, so `linear` in lowercase is an unknown value.
- Applies per storage folder. A world's `region/`, `poi/` and `entities/`
  directories all follow the same world setting, through `ChunkMap` and
  `EntityDataController` respectively.
- Mixed `ANVIL` and `LINEAR` worlds in one process is supported.

## `linear.compression-level`

```yaml
region-format:
  linear:
    compression-level: 9
```

- zstd level used when a dirty region is flushed. Valid 1 to 22, matching
  `Zstd.maxCompressionLevel()` in zstd-jni 1.5.x.
- Does not affect the in-memory hot path. Chunks are staged LZ4-compressed as
  they are written and only re-encoded with zstd at flush time.
- Validated and clamped in three places, so a bad value cannot reach the codec:
  - `@PostProcess` in `WorldConfiguration`: logs and resets to 9.
  - `AbstractRegionFileFactory.clampCompressionLevel`: returns
    `DEFAULT_COMPRESSION_LEVEL` (9) outside `1..MAX_COMPRESSION_LEVEL` (22).
  - The `LinearRegionFile` constructor: `Math.max(1, Math.min(22, level))`.
- The level is recorded as one byte in the file header, but only for
  information. Decoding never reads it, so raising or lowering the setting needs
  no conversion pass. Existing files are rewritten at the new level whenever they
  next flush.
- Kaiiju's version of this check said 1-22 in the message but tested `> 23`.
  This port uses 22, which is the real maximum.

Measured effect on the live SMP tree, region files only, converted offline:

| Dimension | Level 1 | Level 22 | Saved | % |
|---|---|---|---|---|
| Overworld | 17,339,006,898 B | 11,561,937,798 B | 5,777,069,100 B | 33.3% |
| Nether | 165,375,247 B | 111,835,003 B | 53,540,244 B | 32.4% |
| End | 291,280,114 B | 157,860,846 B | 133,419,268 B | 45.8% |
| Total | 17,795,662,259 B | 11,852,762,522 B | 5,942,899,737 B | 33.4% |

Against the original Anvil size of 26,833,329,824 B that is 55.8% saved. The CPU
side of the same run, and why level 6 stays the recommended starting point
while level 9 is the shipped default, is in [benchmarks.md](benchmarks.md).

## `linear.crash-on-broken-symlink`

```yaml
region-format:
  linear:
    crash-on-broken-symlink: true
```

- When a `.linear` path resolves to a broken symlink, the server halts with
  `Linear region file <path> is a broken symbolic link, crashing to prevent data loss`.
- This is a data-loss guard. Continuing would let the chunk system treat the
  region as absent and regenerate it.
- Check symlinks before enabling Linear on a world (or pinning one back):
  `find <world>/region <world>/poi <world>/entities -xtype l`.
- Setting it to `false` downgrades the halt to a warning. Use that only to boot
  for forensics, then fix the underlying path.
- The guard is scoped to the Linear path. Vanilla symlink validation still runs
  first for Anvil files.

## `linear.flush-frequency`, `linear.flush-max-threads` and the inert keys

```yaml
region-format:
  linear:
    flush-frequency: 10
    flush-max-threads: 1
    compression-workers: 0
    long-distance-matching: 0
    log-flush-batches: false
```

- `flush-frequency` (default 10s) gates the age-based flush in
  `minecraft-0012`: `flushDirty()` flushes only files whose first-dirty age is
  `>=` frequency; younger files stay tracked for the next save. Eviction
  (`close()`) forces all regardless of age; bound-pressure flush ignores age.
  Set `0` in tests for immediate drain. `markDirty` keeps FIRST-dirty order (no
  reorder on repeat marks), so the `MAX_DIRTY` victim is the longest-unflushed
  file.
- `flush-max-threads` (default 1) sizes the shared bounded server-wide pool in
  `minecraft-0012` (daemon `linear-flush-*`, fixed size). `<=1` keeps the serial
  loop; `>1` shares one pool across all coordinators with caller participation
  + join barrier.
- `compression-workers` (default 0) is wired in `minecraft-0013`: zstd
  `setWorkers(n)` on the flush stream (fresh stream per flush, setters before
  first write). `0` = single-threaded. Positive values size a worker pool for
  that flush. NATIVE-MEMORY CAUTION: at level 22 a flush context is ~690 MB
  resident / ~5 GB VSZ and `setWorkers(2)` adds ~3.2 GB VSZ for zero speedup
  (single 512 MiB job); at level 1 the default job is 2 MiB so workers CAN
  parallelize (~+4 MB/worker). Never use workers at high levels (`>= ~16`,
  single job, GBs reservation, no gain); safe operating point is low level +
  workers. Level 22 + flush threads `>= 4` OOMs a 6 GiB container.
- `long-distance-matching` (default 0) is wired in `minecraft-0013`: zstd
  `setLong(windowLog)` (LDM) on the flush stream. `0` = off. Valid `10..27`
  (JNI caps at 27; out-of-range silently disables LDM, we skip the call).
  LDM@L1 is cheap (+31 MB) and decodes with stock readers; the reader ships
  `setLongMax(27)` with the writer so any `<= 27` frame decodes. Never
  `setWindowLog` `28..31` without a released reader (old readers refuse with
  "requires too much memory").
- `log-flush-batches` remains inert: `false` keeps warn-only logging, no clamp
  (boolean).
- `flush-frequency < 1` logs
  `[region-format] linear.flush-frequency must be >= 1, got <v>. Falling back to 10.`
  An earlier revision also carried `@Constraints.Min(1)`, which made a value
  below 1 fail boot before the fallback could run. `paper-0009` removes that
  annotation, so the fallback is the shipped behaviour. The consolidated
  `paper-0008` follows the same convention: none of the Linear global keys carry
  `@Constraints`, all clamps live in `@PostProcess`.
- `flush-max-threads` keeps Kaiiju's relative-value semantics: a negative value
  means `availableProcessors + value`, floored at 1. So `-1` would mean all but
  one core. Values `<=1` keep the current serial path.
- `compression-workers: 0` means serial (caller thread). Negative values log
  `[region-format] linear.compression-workers must be >= 0, got <v>. Falling back to 0.`
- `long-distance-matching: 0` disables long-distance matching. Negative values
  log `[region-format] linear.long-distance-matching must be >= 0, got <v>. Falling back to 0.`

## Log lines

Config problems, world still boots:

| Line | Meaning |
|---|---|
| `[region-format] Unknown region format, expected ANVIL or LINEAR. Falling back to ANVIL.` | `format:` misspelled or wrong case. The world is on Anvil despite the intent. |
| `[region-format] linear.compression-level must be 1-22, got <v>. Falling back to 9.` | Level out of range, running at 9. |
| `[region-format] linear.flush-frequency must be >= 1, got <v>. Falling back to 10.` | Frequency below 1. File stays tracked for the next save. |
| `[region-format] linear.compression-workers must be >= 0, got <v>. Falling back to 0.` | Workers below 0, running serial. |
| `[region-format] linear.long-distance-matching must be >= 0, got <v>. Falling back to 0.` | LDM below 0, LDM off. |

Runtime problems, act on these:

| Line | Meaning | Action |
|---|---|---|
| `Linear region file <path> is a broken symbolic link, crashing to prevent data loss` | Symlink guard fired, server halted | Restore or repoint the symlink, then boot |
| `Failed to flush linear region file for folder <dir>, will retry on next save` | A deferred flush failed; the file stays dirty | Check disk space, inodes and permissions on that directory. Repeating every save means roll back |
| `Linear region files cannot be recalculated, regenerating chunk <pos>` | Header mismatch in a `.linear` file, that chunk is regenerated | Note the coordinates and restore the region file from backup if the chunk matters |
| `Attempting to read chunk data at <pos> but got chunk data for <other> instead!` | Chunk/header skew, same as stock | Let recalculation run; repeated storms mean restore from backup |
| `Chunk at (<x>,<z>) in regionfile '<name>' exceeds max size of <n>MiB, it has been deleted from disk` | Oversized chunk removed, stock behaviour preserved | Occasional hits are normal; frequent ones point at a generator or plugin |

The absence of any `[region-format]` line at boot is the healthy case.

## Verifying a live world

- Extension in use: `ls <world>/region/*.linear | wc -l` after a save cycle.
- File identity: `head -c 8 <file>.linear | od -A x -t x1z` starts with
  `c3 ff 13 18 3c ca 9d 9a`. The same eight bytes close the file.
- Flush cadence: `ls -l --time-style=full-iso` across a save cycle. Timestamps
  should advance on save, not on every block edit. Per-edit changes would mean
  the deferred flush is not working.
- Counters: `/linearstats`, see [observability.md](observability.md).
