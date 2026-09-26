# Architecture

How the Linear format is wired into Folia's chunk I/O, and what each patch
contributes. Useful if you are rebasing the fork onto a newer Folia, or trying
to work out why something behaves the way it does.

## On-disk format

Xymb Linear, version 2 on write, versions 1 and 2 accepted on read. Big-endian,
byte-identical to the reference `linear.py`.

```text
header (32 B)  int64  superblock 0xC3FF13183CCA9D9A
               uint8  version = 2
               int64  newest timestamp
               int8   compression level (informational)
               int16  chunk count
               int32  compressed length
               int64  reserved (0)

body           zstd blob, checksums on:
                 1024 x (int32 size, int32 timestamp)
                 raw chunk payloads, concatenated in slot order

footer (8 B)   int64  superblock, same value as the header
```

- 1024 slots per file, one per chunk in the 32x32 region. A null slot means the
  chunk is absent.
- Chunk payloads are opaque. Whatever `write` receives comes back out of
  `getChunkDataInputStream` unchanged.
- No `.mcc` sidecars. A payload over `MAX_CHUNK_SIZE` (500 MiB, the same bound
  vanilla uses) is rejected with an `IOException` rather than spilled to a
  separate file.
- The compression-level byte is written for diagnostics only. Decoding does not
  consult it, which is what makes changing the level a config flip.

## Write path

1. `RegionFileStorage` hands the payload to `LinearRegionFile.write`.
2. The bytes are copied and LZ4-compressed **outside** the lock, into a direct
   buffer.
3. Under `slotLock`, the slot reference is swapped and the file is marked dirty.
   That critical section is a few field writes.
4. `RegionFileStorage` reports the write to `LinearFlushCoordinator.markDirty`.
5. On world save, `flushDirty()` walks the dirty set. Each file snapshots its
   slot tables and clears the dirty flag under the lock, then decompresses LZ4,
   re-encodes the whole region as one zstd stream, and writes it out, all
   unlocked.
6. The write itself is tmp file, force, atomic move.

A write that races a flush either lands in the snapshot or re-marks the file
dirty, so no acknowledged write is lost.

## Read path and dual-read

- `RegionFileStorage` probes `.mca` first, then `.linear`, and opens whichever
  exists through `AbstractRegionFileFactory`.
- The probe runs regardless of the configured format. That is what makes the
  format flag safe to flip in either direction.
- The negative cache is extension-aware, so a miss on one extension does not
  poison the other.
- `RegionStorageUpgrader` uses a spaceless `(mca|linear)` regex and a
  dual-extension filter, so `--forceUpgrade` and `--recreateRegionFiles` see
  both kinds of file.

## Dispatch layer

- `AbstractRegionFile` is the interface both `RegionFile` (Anvil) and
  `LinearRegionFile` implement. The Moonrise chunk-system seams were widened to
  it rather than to `RegionFile`.
- `AbstractRegionFileFactory.get(...)` opens a path in the right implementation
  and clamps the compression level on the way through.
- `AbstractRegionFileFactory.fromConfig()` is the single point that maps a world
  config to a format. Both call sites, in `ServerChunkCache` and `ServerLevel`,
  route through it, so there is one place to look when formats disagree.
- There are two `RegionFileFormat` enums by design: one in the Paper config
  layer (`io.papermc.paper.configuration.type`) and one on the storage side.
  They are joined at `fromConfig()` and nowhere else.

## Flush coordination

`LinearFlushCoordinator`, one instance per storage folder, one shared pool.

- **One shared bounded pool.** A single static `ThreadPoolExecutor` (daemon
  `linear-flush-*` threads, fixed size = `flush-max-threads`) is shared
  server-wide across all coordinators (`minecraft-0012`). A 3-world server has
  9 coordinators (3 worlds x region/poi/entities) sharing one pool, not 9
  pools. Explicitly NOT a `ForkJoinPool` (managed-blocker compensation breaks
  the memory budget), NOT `invokeAll` (cancels on interrupt, truncating the
  durability barrier), and NOT Moonrise's pool (submit-and-block from those
  threads deadlocks). The caller always participates as a worker and joins
  before returning, so `flushDirty()` remains a durability barrier.
  `<=1` keeps the pre-patch serial loop byte-identical (no pool, no futures).
- **Per-folder keying.** Every `RegionFileStorage` owns a distinct folder under
  its dimension path, so the folder key is effectively
  `(ServerLevel, RegionFileType)` without holding a reference to the level.
- **Bounded dirty set.** `MAX_DIRTY = 512`, twice the 256-entry region cache.
  Exceeding it flushes the eldest file inline, which applies backpressure on the
  I/O thread instead of growing unbounded. Duplicates coalesce because the set is
  keyed by file identity.
- **Eviction on unload.** `RegionFileStorage.close()` calls `evict(Path)`, which
  flushes anything still dirty and drops the registry entry, so worlds do not
  leak coordinators. `flush()`/`close()` snapshot the region cache under the
  monitor and run I/O outside it (`minecraft-0011`; flushDirty/evict touch
  only the coordinator set, verified safe).
- Anvil keeps its per-write flush behaviour. Only Linear defers.
- **`doFlush` memory (minecraft-0012).** Each LZ4 slot decompresses straight
  into its final offset in `image` (absolute LZ4 calls, positions untouched).
  The old `plain[]` staging array is gone: peak direct residency is one region
  image (`TABLE_SIZE + totalRaw`), not two. The only heap scratch remains the
  single 32 KiB pump per flush.

## Concurrency and GC rules

- Two locks, always leaf-ordered and never held across file I/O or zstd work.
  `flushGuard` serialises concurrent flushes of the same file (pool threads
  flushing different files do not contend); `slotLock` guards the slot tables
  and the dirty flag. Lock order is `flushGuard` then `slotLock`, with no other
  nesting, so deadlock is not reachable.
- No thread-per-file, no per-coordinator pools. The only threads are the shared
  `linear-flush-*` pool (fixed size, daemon, server-wide) plus callers.
- Hot paths use direct buffers end to end: LZ4 staging is direct-to-direct, the
  flush image is one direct buffer streamed through `ZstdOutputStream`, and file
  I/O goes through `FileChannel`. The only heap scratch is a single 32 KiB pump
  array per flush call, not per chunk.
- `ZstdChunkCodec` refuses non-direct buffers outright, because the zstd-jni
  heap and stream wrappers allocate per call and would churn GC on a
  region-threaded server. This follows the rule established in the Paper PR
  #5029 review.
- Region load is a cold path and may allocate transient heap arrays.
- The timing counters added later use `LongAdder` and `LongAccumulator` only. No
  `synchronized` was added to any hot record path.

## Inherited bugs that were fixed, not ported

Kaiiju's implementation was the architectural reference. Three defects in it
were identified during the port and corrected here:

- An extension predicate joining two `!endsWith` checks with `||`, which is
  always true. The region-file lookup it guarded therefore always returned
  null.
- A symlink guard comparing a format enum against a string with `.equals`,
  which is never true, so the guard was dead code.
- An upgrader regex written as `(linear | mca)`, with a space inside the
  alternation. It matched a literal `linear ` and so never matched a real
  `.linear` file during upgrade scans.

The port carries a grep gate for all three patterns (`|| !endsWith`,
`format.equals(`, `(linear | mca)`) so they cannot reappear.

## Patch inventory

Applied in numeric order by paperweight, `minecraft-*` into
`folia-server/minecraft-patches/features/` and `paper-*` into
`folia-server/paper-patches/features/`. Full map:
`versions/26.1.x/patches/MODULES.md`.

| Patch | Contents |
|---|---|
| `minecraft-0009` | Region format: `LinearRegionFile`, dispatch layer, coordinator, codec, dual-read probe, symlink guard, recreate/upgrade paths |
| `minecraft-0010` | Observability: timing counters, `linear$stats()`, measurement fields |
| `minecraft-0011` | Flush-unlock: snapshot under monitor, I/O outside it |
| `minecraft-0012` | Flush coordinator: shared pool, age-based flush, opportunistic drain, direct-into-image, bridge call site |
| `minecraft-0013` | zstd tuning: workers, LDM, reader window |
| `minecraft-0014` + `paper-0010` | Defaults flip: ANVIL/1 → LINEAR/9 through v1.2.x, LINEAR/6 from v1.3.0 |
| `minecraft-0015` + `paper-0011` | Startup conversion trigger |
| `minecraft-0016` | Conversion pipeline: convert → validate → delete |
| `minecraft-0017` | Save drain: autosave, explicit-save and shutdown hooks |
| `paper-0008` | Config blocks, format enum, clamps, dual-read tests |
| `paper-0009` | `/linearstats`, flush event + bridge, API delegate |

lz4 is not pinned as a dependency. Vanilla and mache already supply
`net.jpountz.lz4`, and pinning a second copy of the same package would duplicate
it on the classpath.

## Rebasing notes

The surfaces most likely to break on a Folia update:

- Moonrise chunk-system seams, `SimpleRegionStorage`, `RegionStorageUpgrader`.
- Any `forceWrite` path, since Linear's durability contract differs from Anvil's.
- The `build.gradle.kts.patch` hunk that `versions/<line>/build-hunk.py` splices.
  It aborts on drift rather than producing a wrong file.
- zstd-jni version bumps, which can move `Zstd.maxCompressionLevel()`.
- `PaperCommands`, if upstream moves from the legacy static registry to
  brigadier-only registration.
