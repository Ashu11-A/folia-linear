# Observability

The fork exposes Linear I/O counters three ways: a command, an event, and a
Paper API delegate. All of it is read-only instrumentation. It adds no config
keys, changes no behaviour, and records nothing on the Anvil path.

## `/linearstats`

- No arguments, and tab completion is empty.
- Permission `sexidium.command.linearstats`, OP by default. It is mirrored from
  `tps` in code; if your base declares `tps` in `permissions.yml` instead of
  defaulting it to OP, add the same entry there.
- Without the permission the sender gets
  `You do not have permission to use linearstats.` and no rows at all.
- On a node that has done no Linear I/O yet, the output is
  `linearstats: no Linear folders tracked (no linear I/O yet).` On an Anvil-only
  node that is the expected result, not a fault.

Output shape:

```
<world> [<folderType>]: read=N (avg N us) write=N (avg N us) flush=N (avg N us) load=N filesFlushed=N dirtyDepth=N failures=N
TOTALS: read=N (avg N us) write=N (avg N us) flush=N (avg N us) load=N filesFlushed=N failures=N folders=N
```

| Field | Meaning |
|---|---|
| `world` | Parent directory name of the storage folder, from `.../<world>/<type>` |
| `folderType` | One of `region`, `poi`, `entities`, inferred from the folder path suffix and defaulting to `region` |
| `read` / `write` / `flush` | Operation counts, with averages as total microseconds divided by count, or 0 when the count is 0 |
| `load` | Region file loads |
| `filesFlushed` | Only successful flushes. Clean no-op flushes record nothing |
| `dirtyDepth` | Current size of the coordinator's dirty set, per folder row only |
| `failures` | `flushOne` retries |
| `folders` | Number of tracked folders, `TOTALS` row only |

Data is pulled on demand from `LinearFlushCoordinator.snapshots()` and
`RegionFileStorage#sexidium$stats()`. Nothing is pushed or buffered for the
command.

## `LinearRegionFlushCompletedEvent`

`org.bukkit.event.world.LinearRegionFlushCompletedEvent`.

- **Async by contract.** It is constructed with `super(true)` and fired off the
  I/O threads through the async scheduler, never on the Moonrise I/O thread.
- Granularity is one event per coordinator `flushDirty()` that attempted at
  least one file. A flush cycle with nothing dirty fires nothing, so an idle
  server producing no events is correct.
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

`io.papermc.paper.linear.SexidiumLinearStats` lets a plugin read the same
counters without importing anything from `net.sexidium`.

- `snapshots()` returns every tracked folder; `snapshot(folderKey)` returns one.
- The DTO is `FolderSnapshot(folderKey, folderType, worldName, reads,
  readMicrosAvg, writes, writeMicrosAvg, flushes, flushMicrosAvg,
  compressionLevel, filesFlushed, failures, dirtyNow)`, built from JDK types
  only.
- Averages are computed as total divided by count, guarded against division by
  zero.

## Wiring the event

The event needs one call site that this patch set does not provide.

- `SexidiumLinearFlushBridge#notifyFlush(Plugin, String, long, long)` ships
  without a caller. An integrator has to invoke it after
  `LinearFlushCoordinator.flushDirty()` in the Paper-side world save path.
- Until that is wired, `/linearstats` and the API delegate still work, because
  both pull directly from the coordinator. Only the event stays silent.
- The bridge takes the owning `Plugin` explicitly rather than looking it up, so
  it works from a patch context.

## Troubleshooting

- **No rows, but `.linear` files exist.** The counters only populate on actual
  Linear I/O. Trigger a save cycle, then check again.
- **Event never fires.** Either the bridge is unwired, or nothing is dirty.
  Confirm with `/linearstats` that flushes are being counted.
- **`folderType` shows `region` for `poi/` or `entities/`.** The inference in
  `SexidiumLinearFolderNames` reads the absolute folder-path suffix; a
  non-standard layout falls back to `region`.
- **Permission denied.** Grant OP or `sexidium.command.linearstats`.

## Tests

- `tests/LinearTimingInstrumentationTest.java` covers the counters: empty state,
  write and flush counts, reopen and read, monotonicity, reset.
- `tests/LinearStatsCommandTest.java` covers the readout: snapshot aggregation,
  per-file deltas, batch equality, failures tightening `filesFlushed`, clean
  no-op behaviour, and the event shape by reflection.
