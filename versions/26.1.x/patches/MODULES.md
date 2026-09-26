# v1.2.0 patch modules (`versions/26.1.x/patches/`)

13 feature patches: 9 `minecraft-*` (NMS/storage tree) + 4 `paper-*` (config/command tree).
Build tooling globs `*.patch` only, so this file is never staged as a patch
(`scripts/build.sh`, `scripts/preflight.sh` §3).

Hunk counts post-assembly (`grep -c '^@@'`):
`minecraft-0009`=67, `0010`=27, `0011`=7, `0012`=12, `0013`=4, `0014`=9,
`0015`=3, `0016`=1, `0017`=7, `paper-0008`=7, `paper-0009`=7, `paper-0010`=3,
`paper-0011`=1.

## 1. Module table

| Patch | Contents |
|---|---|
| `minecraft-0009-Linear-region-format` | `LinearRegionFile` (v2 writer, v1/v2 reader), `LinearDirectStreams`, `AbstractRegionFile` + `AbstractRegionFileFactory` (incl. `fromConfig()` single mapping point, `clampCompressionLevel`), storage-side `RegionFileFormat`, `LinearFlushCoordinator` (bounded dirty set, `MAX_DIRTY = 512`), `ZstdChunkCodec`, dual-read probe, broken-symlink guard, recreate/upgrade paths |
| `minecraft-0010-Linear-region-observability` | Lock-free timing counters (`LinearRegionTimings`) on read/write/flush/load paths, `linear$stats()`, `snapshots()`; `rawBytes`/`compressedBytes`, bucketed flush p50/p99, `millisSinceLastFlush` |
| `minecraft-0011-Linear-flush-unlock` | `RegionFileStorage.flush()`/`close()` snapshot under the monitor with I/O outside it; eviction `removeLast().close()` outside the monitor |
| `minecraft-0012-Linear-flush-coordinator` | One shared bounded server-wide flush pool behind `flush-max-threads` (daemon `linear-flush-*`, caller participates + joins as durability barrier; `<= 1` keeps the serial path) plus fire-and-forget periodic drain pool (`linear-flush-async-*`, min-1 threads, submit-no-join, inline on reject); age-based flush behind `flush-frequency` (first-dirty age, longest-unflushed first); opportunistic age-eligible drain on `markDirty`; `doFlush` writes direct-into-image; flush-bridge `notifyFlushSync` call site (relocated to async task end) |
| `minecraft-0013-Linear-zstd-tuning` | Writer `setWorkers(n)` / `setLong(windowLog)` + reader `setLongMax(27)`; defaults 0 = inert; setters before first write |
| `minecraft-0014-Linear-default-format` | Shipped defaults ANVIL→LINEAR, level 1→6 (`WorldConfiguration`, `DEFAULT_COMPRESSION_LEVEL`, config fallback, conversion level) |
| `minecraft-0015-Linear-startup-conversion` | Startup conversion trigger: before plugin init, worlds whose active format resolves to LINEAR convert leftover `.mca` files |
| `minecraft-0016-Linear-conversion-pipeline` | `LinearRegionConverter`: per-file CONVERT → VALIDATE → DELETE on a bounded pool, strict per-file order; validation = target existence + header sanity + chunk-count parity + full decompression; 3 retries, then protection halt; shadows/divergences escalate, never auto-delete; `new_*` crash orphans cleaned next run |
| `minecraft-0017-Linear-save-drain` | `LinearFlushCoordinator.flushAllDirty(force)` + `evictAll()`; periodic call sites fire-and-forget (`ChunkMap.processUnloads`, autosave/`saveLevelData`, non-forced `ServerChunkCache.save` → `flushDirtyAsync(false)` submit-no-join); forced/stop sites stay joining (`flushAllDirty(true)`, `evictAll()` in `saveAllChunks`/`ServerLevel.close`/`RegionShutdownThread` post-`stopServer` stop drain + pool `shutdown()` stop hook) |
| `paper-0008-Linear-config` | `region-format` blocks in `GlobalConfiguration`/`WorldConfiguration`, config-side `RegionFileFormat` enum, `@PostProcess` clamps (no `@Constraints` on Linear keys), dual-read test sources |
| `paper-0009-Linear-linearstats` | `/linearstats` Adventure panel, `LinearRegionFlushCompletedEvent` + async bridge, `LinearFolderNames`, `io.papermc.paper.linear.LinearStats` API delegate (incl. the 5 measurement fields) |
| `paper-0010-Linear-default-format` | Paper-side defaults flip (config default + fallback 1→6); carries `LinearDefaultFormatTest` |
| `paper-0011-Linear-startup-conversion` | Paper-side startup conversion wiring |

## 2. Old → new number map (v1.1.0 18 patches → v1.2.0 13)

Consolidation is comment-only except `paper-0009`'s 5 measurement API fields
and the B/F behavior modules. Superseded hunks resolve newer-wins by
construction; kept text is v1.1.0 tip behavior.

| Old patch (v1.1.0) | Disposition |
|---|---|
| `minecraft-0009`, `0010`, `0011` | Folded → new `minecraft-0009` |
| `minecraft-0012`, `0015` | Folded → new `minecraft-0010` |
| `minecraft-0013`, `0014` | Folded → new `minecraft-0011` |
| `minecraft-0016`, `0017`, `0019`, `0020` | Folded → new `minecraft-0012` |
| `minecraft-0018` | → new `minecraft-0013` |
| `paper-0008`, `paper-0009`, `paper-0012` | Folded → new `paper-0008` |
| `paper-0010`, `paper-0011`, `paper-0013` | Folded → new `paper-0009` |

New in v1.2.0 (no v1.1.0 predecessor): `minecraft-0014`/`0015`/`0016`/`0017`,
`paper-0010`/`paper-0011`.

## 3. Apply order

Paperweight applies each family in filename-sort order; numbering is chosen so
sort order = apply order:

- minecraft: `0009` (format) → `0010` (observability) → `0011` (flush-unlock) → `0012` (coordinator) → `0013` (zstd) → `0014` (defaults) → `0015` (trigger) → `0016` (pipeline) → `0017` (save-drain)
- paper: `0008` (config) → `0009` (linearstats) → `0010` (defaults) → `0011` (trigger)

No cross-stack file overlap (minecraft = `net/...` tree, paper = `src/...`
tree). Runtime dependency only: the paper panel/API reads the
`minecraft-0010` snapshot fields, and the `minecraft-0012` bridge overload is
wired by the coordinator bridge call site.

lz4 is not pinned as a dependency. Vanilla and mache already supply
`net.jpountz.lz4`; a second copy would duplicate it on the classpath.
