# Configuration reference

Every setting the Linear patches add lives under a `region-format` block. Two of
them sit in the world config, three in the global config. The README covers the
two you will actually tune; this page is the full surface, including what the
server does with a bad value.

## Key map

| Key | Config file | Scope | Type | Default |
|---|---|---|---|---|
| `region-format.format` | `paper-world.yml`, `paper-world-defaults.yml` | per world | `ANVIL` / `LINEAR` | `ANVIL` |
| `region-format.linear.compression-level` | same | per world | int 1-22 | `1` |
| `region-format.linear.crash-on-broken-symlink` | same | per world | bool | `true` |
| `region-format.linear.flush-frequency` | `paper-global.yml` | server | int >= 1 | `10` |
| `region-format.linear.flush-max-threads` | `paper-global.yml` | server | int | `1` |

The world keys are defined in `WorldConfiguration`, the global ones in
`GlobalConfiguration`, both in `patches/paper-0008-*.patch`.

## Placement

- `paper-world-defaults.yml` holds the fallback for every world. The block goes
  at the top level, not under `chunks`.
- `config/worlds/<world>/paper-world.yml` overrides it for one world. Leave the
  file without a `region-format` block and the world inherits the default.
- `paper-global.yml` holds the two flush keys, also at the top level.
- Restart after editing. None of these keys are re-read at runtime.

Templates you can paste directly:

- `release/paper-world-defaults.region-format.yml`
- `release/paper-world.region-format.yml`
- `release/paper-global.region-format.yml`

## `format`

```yaml
region-format:
  format: LINEAR
```

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
    compression-level: 1
```

- zstd level used when a dirty region is flushed. Valid 1 to 22, matching
  `Zstd.maxCompressionLevel()` in zstd-jni 1.5.x.
- Does not affect the in-memory hot path. Chunks are staged LZ4-compressed as
  they are written and only re-encoded with zstd at flush time.
- Validated and clamped in three places, so a bad value cannot reach the codec:
  1. `@PostProcess` in `WorldConfiguration`: logs and resets to 1.
  2. `AbstractRegionFileFactory.clampCompressionLevel`: returns
     `DEFAULT_COMPRESSION_LEVEL` (1) outside `1..MAX_COMPRESSION_LEVEL` (22).
  3. The `LinearRegionFile` constructor: `Math.max(1, Math.min(22, level))`.
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
side of the same run, and why level 1 is still the recommended starting point,
is in [benchmarks.md](benchmarks.md).

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
- Check symlinks before opting a world in:
  `find <world>/region <world>/poi <world>/entities -xtype l`.
- Setting it to `false` downgrades the halt to a warning. Use that only to boot
  for forensics, then fix the underlying path.
- The guard is scoped to the Linear path. Vanilla symlink validation still runs
  first for Anvil files.

## `linear.flush-frequency` and `linear.flush-max-threads`

```yaml
region-format:
  linear:
    flush-frequency: 10
    flush-max-threads: 1
```

- Both are inert in this release. They are declared, documented and validated,
  but no code reads them. There is no flush scheduler and no flush thread pool;
  flushing happens on Moonrise I/O threads at save time. Tuning these values
  changes nothing.
- They exist so the config surface matches Kaiiju's, which makes a future
  scheduler a wiring change rather than a config break.
- `flush-frequency < 1` logs
  `[region-format] linear.flush-frequency must be >= 1, got <v>. Falling back to 10.`
  An earlier revision also carried `@Constraints.Min(1)`, which made a value
  below 1 fail boot before the fallback could run. `paper-0009` removes that
  annotation, so the fallback is the shipped behaviour.
- `flush-max-threads` keeps Kaiiju's relative-value semantics: a negative value
  means `availableProcessors + value`, floored at 1. So `-1` would mean all but
  one core, if anything read it.

## Log lines

Config problems, world still boots:

| Line | Meaning |
|---|---|
| `[region-format] Unknown region format, expected ANVIL or LINEAR. Falling back to ANVIL.` | `format:` misspelled or wrong case. The world is on Anvil despite the intent. |
| `[region-format] linear.compression-level must be 1-22, got <v>. Falling back to 1.` | Level out of range, running at 1. |
| `[region-format] linear.flush-frequency must be >= 1, got <v>. Falling back to 10.` | Frequency below 1. Inert either way. |

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
