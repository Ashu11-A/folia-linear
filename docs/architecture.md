# Architecture

How the Linear format is wired into Folia's chunk I/O, and what each patch
contributes. Useful if you are rebasing the fork onto a newer Folia, or trying
to work out why something behaves the way it does.

## On-disk format

Xymb Linear, version 2 on write, versions 1 and 2 accepted on read. Big-endian,
byte-identical to the reference `linear.py`.

```
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

`LinearFlushCoordinator`, one instance per storage folder.

- **No threads.** The class never spawns or parks a thread. Flushing runs on the
  caller, which is always a Moonrise region I/O thread or the server save
  thread.
- **Per-folder keying.** Every `RegionFileStorage` owns a distinct folder under
  its dimension path, so the folder key is effectively
  `(ServerLevel, RegionFileType)` without holding a reference to the level.
- **Bounded dirty set.** `MAX_DIRTY = 512`, twice the 256-entry region cache.
  Exceeding it flushes the eldest file inline, which applies backpressure on the
  I/O thread instead of growing unbounded. Duplicates coalesce because the set is
  keyed by file identity.
- **Eviction on unload.** `RegionFileStorage.close()` calls `evict(Path)`, which
  flushes anything still dirty and drops the registry entry, so worlds do not
  leak coordinators.
- Anvil keeps its per-write flush behaviour. Only Linear defers.

## Concurrency and GC rules

- Two locks, always leaf-ordered and never held across file I/O or zstd work.
  `flushGuard` serialises concurrent flushes; `slotLock` guards the slot tables
  and the dirty flag. Lock order is `flushGuard` then `slotLock`, with no other
  nesting, so deadlock is not reachable.
- No global static state, no thread-per-file, no private thread pools.
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

- A dual-read predicate using `||` where `&&` was required, which made the probe
  accept paths it should have rejected.
- An enum comparison by value where identity was intended, in the symlink guard.
- A region-file regex written with a space inside the alternation
  (`(linear | mca)`), which never matched `.linear` files during upgrade scans.

The port carries a grep gate for all three patterns so they cannot reappear.

## Patch inventory

Applied in numeric order by paperweight, `minecraft-*` into
`folia-server/minecraft-patches/features/` and `paper-*` into
`folia-server/paper-patches/features/`.

| Patch | Contents |
|---|---|
| `minecraft-0009` | `LinearRegionFile`, `LinearDirectStreams`, `AbstractRegionFile`, `AbstractRegionFileFactory`, storage-side `RegionFileFormat`, `LinearFlushCoordinator`, `ZstdChunkCodec`, the dual-read probe, and the broken-symlink guard method |
| `minecraft-0010` | `crash-on-broken-symlink` field plus the constructor chain through `RegionFileStorage`, `IOWorker`, `SimpleRegionStorage`, `EntityDataController`, `ChunkMap` and `PoiManager`; the two guard call sites; zstd-jni 1.5.6-8 dependency |
| `minecraft-0011` | Recreate path honours the world format (`RecreatingSimpleRegionStorage`, extension-aware replace, pre-move flush); coordinator-aware batching in `MoonriseRegionFileIO`; `fromConfig()` single mapping point; oversized-chunk guard on both write paths; upgrade-rewrite entry un-stubbed |
| `minecraft-0012` | Lock-free timing counters on the Linear read, write, flush and load paths, plus `sexidium$stats()` and `snapshots()`. No behaviour change, and the Anvil path stays byte-identical |
| `paper-0008` | The `region-format` config blocks in `GlobalConfiguration` and `WorldConfiguration`, the config-side `RegionFileFormat` enum, and the dual-read test sources |
| `paper-0009` | Removes `@Constraints.Min(1)` from `flush-frequency` so the documented fallback is reachable; world-loader wiring; upgrade un-stub |
| `paper-0010` | `/linearstats` command, `LinearRegionFlushCompletedEvent`, the async bridge that fires it, and `SexidiumLinearFolderNames` |
| `paper-0011` | `io.papermc.paper.linear.SexidiumLinearStats`, a JDK-only DTO so plugins can read stats without importing `net.sexidium` |

lz4 is not pinned as a dependency. Vanilla and mache already supply
`net.jpountz.lz4`, and pinning a second copy of the same package would duplicate
it on the classpath.

## Rebasing notes

The surfaces most likely to break on a Folia update:

- Moonrise chunk-system seams, `SimpleRegionStorage`, `RegionStorageUpgrader`.
- Any `forceWrite` path, since Linear's durability contract differs from Anvil's.
- The `build.gradle.kts.patch` hunk that `scripts/apply-deps-hunk.py` splices.
  It aborts on drift rather than producing a wrong file.
- zstd-jni version bumps, which can move `Zstd.maxCompressionLevel()`.
- `PaperCommands`, if upstream moves from the legacy static registry to
  brigadier-only registration.
