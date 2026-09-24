# Observability

The fork exposes Linear I/O counters three ways: a command, an event, and a
Paper API delegate. All of it is read-only instrumentation. It adds no config
keys, changes no behaviour, and records nothing on the Anvil path.

## `/linearstats` (paper-0013 Adventure panel)

- No arguments, and tab completion is empty.
- Permission `linear.command.linearstats`, OP by default. It is mirrored from
  `tps` in code; if your base declares `tps` in `permissions.yml` instead of
  defaulting it to OP, add the same entry there.
- Without the permission the sender gets
  `You do not have permission to use linearstats.` and no rows at all.
- On a node that has done no Linear I/O yet, the output is
  `linearstats: no Linear folders tracked (no linear I/O yet).` On an Anvil-only
  node that is the expected result, not a fault. The empty-state line is pinned
  (same text as the legacy readout).

Output shape (coloured, aligned; per-world `region|poi|entities` sections):

```
Linear stats (N folders)
<world>  lvl <level>  last flush <age> / never flushed
  [region]   r=N (avg Nus) w=N (avg Nus) f=N (avg Nus) l=N
    files=N fail=N dirty [███░░░░░░░] 3/512  4.5MiB→1.2MiB (73% saved)  p50 2.1ms p99 15ms  12s ago / never flushed
  [poi]      ...
  [entities] ...
TOTALS: read=N (...) write=N (...) flush=N (...) load=N files=N fail=N folders=N  11.0MiB→7.3MiB (34% saved)
```

| Field | Meaning |
|---|---|
| `world` | Parent directory name of the storage folder, from `.../<world>/<type>` |
| `lvl` | Per-world zstd compression level (world config `region-format.linear.compression-level`; `?` when the world is unavailable) |
| `last flush` / per-row age | `millisSinceLastFlush` humanized (`never` when `-1`, else `12ms` / `3.2s` / `2m 5s` + ` ago` per row) |
| `folderType` | One of `region`, `poi`, `entities`, inferred from the folder path suffix and defaulting to `region` |
| `read` / `write` / `flush` | Operation counts, with human averages (`12us` / `1.2ms` / `2.30s`), or `0us` when the count is 0 |
| `load` | Region file loads |
| `files` | Only successful flushes (`filesFlushed`). Clean no-op flushes record nothing |
| `fail` | `flushOne` retries |
| `dirty [bar] N/512` | Current dirty depth with a 10-cell bar (`█` filled, `░` empty, scaled to `MAX_DIRTY=512`) |
| `raw→packed (% saved)` | Summed flush image bytes, humanized (`512B` / `1.2MiB` / `3.40GiB`); `no bytes yet` when `raw==0` |
| `p50` / `p99` | Bucketed flush latency estimates, humanized (upper-bound buckets, clean-no-ops excluded) |
| `folders` | Number of tracked folders, `TOTALS` row only |

Data is pulled on demand from `LinearFlushCoordinator.snapshots()` and
`RegionFileStorage#linear$stats()`. Nothing is pushed or buffered for the
command.

## Loop-4 measurements (`minecraft-0015`, wired to the panel in `paper-0013`)

`LinearFolderSnapshot` carries lock-free measurements the legacy command hid;
`paper-0013` wires them to the display (no counter gap, display only):

- `rawBytes` / `compressedBytes`: summed flush image bytes (uncompressed vs
  zstd) across actual I/O flushes. Ratio estimates live savings without a
  converter run.
- `flushP50Micros` / `flushP99Micros`: bucketed latency estimates (upper-bound
  buckets 1ms..1s+, 10 buckets, `LongAdder` only). Clean-no-ops excluded,
  same as `flush.count`.
- `millisSinceLastFlush`: wall ms since the last successful folder flush
  (`-1` when never flushed). Answers "is this folder stalled?" without logs.
- `markDirty`, `cacheHits`/`cacheMisses`: S8 blind-spot fix. An absent snapshot
  entry means "never invoked" (no Linear I/O yet for that folder); a present
  entry with zero counts means "empty set" (invoked but idle). `/linearstats`
  shows "no folders tracked" for the former; check `markDirty`/`cache*` to
  separate the latter.

All five use `LongAdder`/`LongAccumulator` only, no `synchronized` on hot
paths, no threads, no pool re-cut of `recordFlush`.

## `LinearRegionFlushCompletedEvent` (wired in paper-0013 + minecraft-0019)

`org.bukkit.event.world.LinearRegionFlushCompletedEvent`.

- **Async by contract.** It is constructed with `super(true)`. The async entry
  (`LinearFlushBridge#notifyFlush(Plugin,…)`) schedules off the I/O threads
  through the async scheduler; the server-internal entry
  (`#notifyFlushSync(…)`, paper-0013, no Plugin) fires sync on the save thread
  right after `flushDirty()` drains (NMS call site in minecraft-0019, same
  PATCH8). Listeners still observe async semantics (must not touch world state;
  schedule back through the region scheduler if needed).
- Granularity is one event per coordinator `flushDirty()` that attempted at
  least one file. A flush cycle with nothing dirty (or nothing old enough for
  the age gate) fires nothing, so an idle server producing no events is correct.
- Carries `worldName`, `folderType` (`region`, `poi` or `entities`) and a
  post-flush totals snapshot as primitives.
- Listeners run async and must not touch world state directly. Schedule back
  through the region scheduler if you need to.

```java
@EventHandler
public void onLinearFlush(LinearRegionFlushCompletedEvent e) {
    // Async: do not touch world state here; schedule back if needed.
    getLogger().info(e.getWorldName() + "[" + e.getFolderType() + "] flushed=" + e.getFilesFlushed());
}
```

## Paper API delegate

`io.papermc.paper.linear.LinearStats` lets a plugin read the same
counters without importing anything from `net.linear`.

- `snapshots()` returns every tracked folder; `snapshot(folderKey)` returns one.
- The DTO is `FolderSnapshot(folderKey, folderType, worldName, reads,
  readMicrosAvg, writes, writeMicrosAvg, flushes, flushMicrosAvg,
  compressionLevel, filesFlushed, failures, dirtyNow)`, built from JDK types
  only.
- Averages are computed as total divided by count, guarded against division by
  zero.

## Wiring the event (done in PATCH8)

- `LinearFlushBridge#notifyFlushSync(String, long, long)` (paper-0013, no
  Plugin) is called right after `LinearFlushCoordinator.flushDirty()` drains
  (NMS call site in minecraft-0019, same PATCH8 work; `filesAttempted` is the
  snapshot size, `elapsedMicros` spans the durability barrier). Clean-no-ops
  (`<1` attempted, or nothing old enough for the age gate) fire nothing.
- `LinearFlushBridge#notifyFlush(Plugin, String, long, long)` (async) remains
  for Paper-side callers with an owning Plugin (Folia-safe off-IO delivery);
  the old `getProvidingPlugin` misuse stays fixed via explicit param.
- Until PATCH8, `/linearstats` and the API delegate worked (pull) but the event
  stayed silent (no call site). After PATCH8 it fires.

## Troubleshooting

- **No rows, but `.linear` files exist.** The counters only populate on actual
  Linear I/O. Trigger a save cycle, then check again.
- **Event never fires.** Either nothing is dirty/old enough (age gate), or the
  bridge call site is missing (pre-PATCH8 builds). Confirm with `/linearstats`
  that flushes are being counted.
- **`folderType` shows `region` for `poi/` or `entities/`.** The inference in
  `LinearFolderNames` reads the absolute folder-path suffix; a
  non-standard layout falls back to `region`.
- **Permission denied.** Grant OP or `linear.command.linearstats`.

## Tests

- `tests/LinearTimingInstrumentationTest.java` covers the counters: empty state,
  write and flush counts, reopen and read, monotonicity, reset.
- `tests/LinearStatsCommandTest.java` covers the readout: snapshot aggregation,
  per-file deltas, batch equality, failures tightening `filesFlushed`, clean
  no-op behaviour, panel-data wiring (`rawBytes`/`compressedBytes`/`p50`/`p99`/
  `millisSince`/`dirtyDepth` all present for the Adventure panel), and the
  event shape by reflection.
