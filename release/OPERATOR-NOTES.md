# OPERATOR-NOTES — Sexidium-Folia Linear rollout (ANVIL-default)

Audience: the operator holding the pager during opt-in. Keep `rollback.sh`
and a verified backup within reach before touching any flag.

## 1. Posture: ANVIL default, mixed deployment is the supported end state

- Every world starts `region-format.format: ANVIL`. Writers behave exactly
  as stock; readers additionally probe for `.linear` (harmless when absent).
- Worlds that benefit stay `LINEAR`; worlds that do not stay `ANVIL`. Mixed
  `ANVIL`/`LINEAR` across worlds in one process is EXPECTED, not degraded.
- Extension switch is per `RegionFileStorage` (chunk/POI via `ChunkMap`,
  entities via `EntityDataController`); dual-read probe covers both.
- `compression-level` default `1`. Tune only after a full soak cycle.
- `crash-on-broken-symlink` default `true`: a broken `.linear` symlink HALTS
  the server by design (data-loss guard). Resolve symlinks BEFORE flipping.

## 2. Per-world opt-in procedure

1. **Backup (quiesced):** stop the server or quiesce the world, then snapshot
   `region/`, `poi/`, `entities/` for the target world. Record it:
   `date -u +%FT%TZ > /backup/<world>/BACKUP_VERIFIED`.
   `rollback.sh` refuses to run without this marker.
2. **Health check:** no zero-byte `r.*.mca`; no broken symlinks:
   `find <world>/region <world>/poi <world>/entities -xtype l` must be empty.
3. **Baseline:** `du -sb region poi entities`; counts of `*.mca` vs `*.linear`.
4. **Flip ONE world** (low-risk first, NEVER spawn, NEVER all worlds at once):
   in that world's `paper-world.yml` ONLY, set
   `region-format.format: LINEAR` (leave `compression-level: 1` for the soak).
   Template: `templates/paper-world.region-format.yml`.
5. **Restart.** Watch the log (§3). Soak ≥ 1 full save cycle + 1 restart
   (Linear buffers flush on cadence; the restart proves files re-open).
6. **Expand** one world at a time, highest-churn worlds last.

## 3. Monitoring — what proves what

### 3a. Proof Linear I/O is happening (healthy)

| Signal | How to check | Why it proves it |
|---|---|---|
| New `r.X.Z.linear` files grow on writes | `ls <world>/region/*.linear \| wc -l` + `du -sb` after a save cycle + restart | Writer dispatch routes through `extensionFor(format)` → `.linear`; stock never emits that extension |
| Linear superblock magic on disk | `head -c 8 <file>.linear \| od -A x -t x1z` starts with `c3 ff 13 18 3c ca 9d 9a` (trailer repeats the same 8 bytes) | On-disk proof independent of logs (`LINEAR_SIGNATURE 0xC3FF13183CCA9D9A`; check both head and tail) |
| Deferred-flush behaviour: `.linear` mtimes/counts advance on save cadence, not on every edit | Observe `ls -l --time-style=full-iso` across a save cycle | Matches `LinearFlushCoordinator` design (dirty-tracked, `flushDirty()` on world save; no per-edit fsync storm) |
| Offline chunk-set equality after conversion | `python3 /tmp/fork-study-adapt/convert.py verify <mca-tree> <mca-tree>` → `total diffs=0` | Payload-level proof the converter path preserves chunks |

### 3b. Config fallback lines (world runs, but NOT as intended — fix the YAML)

- `[region-format] Unknown region format, expected ANVIL or LINEAR. Falling back to ANVIL.`
  → `format:` misspelled (e.g. lowercase `linear`). World is on ANVIL despite intent.
- `[region-format] linear.compression-level must be 1-22, got <v>. Falling back to 1.`
  → out-of-range level; running at `1`.
- `[region-format] linear.flush-frequency must be >= 1, got <v>. Falling back to 10.`
  → NOTE: with the shipped `@Constraints.Min(1)` this postProcess line is
  normally UNREACHABLE — a `< 1` value fails boot instead (see §4). If you see
  a boot `SerializationException "...less than the min 1"`, that is this key.

### 3c. Trouble lines (act)

| Line (substring) | Meaning | Action |
|---|---|---|
| `Linear region file <path> is a broken symbolic link, crashing to prevent data loss` | Symlink guard fired (`crash-on-broken-symlink: true`), server halts | Resolve/replace the symlink from backup, or temporarily set the flag `false` to boot read-only-forensics (then fix properly) |
| `Failed to flush linear region file for folder <dir>, will retry on next save` (WARN) | A deferred flush failed; file stays dirty, retried next save | Check disk space/inodes/permissions on `<dir>`; if it repeats every save, stop and roll back rung A |
| `Linear region files cannot be recalculated, regenerating chunk <pos>` | Header mismatch in a `.linear` file; chunk regenerated (data loss for that chunk) | Note the coords; restore that region file from backup if the chunk matters |
| `Attempting to read chunk data at <pos> but got chunk data for <other> instead!` | Chunk/header skew (either format) | Same as stock: let recalculation run; persistent storms → restore from backup |
| `Can't recalculate regionfile header, regenerating chunk <pos>` | Unrecoverable header (either format) | Restore the region file from backup |
| `Chunk at (<x>,<z>) in regionfile '<name>' exceeds max size of <n>MiB, it has been deleted from disk` | Oversized chunk deleted (either format; stock behaviour preserved) | Expected occasionally on corrupt/oversize chunks; frequent hits → investigate generator/plugins |
| `MCC-AUDIT: <n> .mcc sidecar(s) ... SKIPPED` (converter stderr) | Anvil-side oversize sidecars present; converter skips them loudly | Confirm sidecars are carried alongside any manual copy; linear write path has no `.mcc` handling |
| `ERROR converting <path>: ...` (converter) | Per-file conversion failure | Live tree untouched; fix the file (often zero-byte) and re-run |

### 3d. `linearstats` readout (L1-TIMING/L2-STATS, observability only)

- Command syntax: `/linearstats` (no args; empty `tabComplete`). Permission
  `sexidium.command.linearstats` defaults to OP, mirrored from `tps` in code;
  if the base declares `tps` in `permissions.yml`/default-OP instead, mirror
  `sexidium.command.linearstats` there too (see `CommandLinearStats` javadoc).
- Denial path: without the permission the sender gets
  `You do not have permission to use linearstats.` and no rows (`execute`
  returns `false` via `testPermission`; **denied = message only, no stats**).
- No-data line: `linearstats: no Linear folders tracked (no linear I/O yet).`
  (**expected** on ANVIL-only nodes with no `.linear` I/O yet — not an error).

| Field | Where | What proves what |
|---|---|---|
| Per-folder row | `%s [%s]: read=%d (avg %d us) write=%d (avg %d us) flush=%d (avg %d us) load=%d filesFlushed=%d dirtyDepth=%d failures=%d` (`world` [`folderType`]) | Pull-only via `LinearFlushCoordinator.snapshots()` / `RegionFileStorage#sexidium$stats()`; `folderType` pinned to `region\|poi\|entities` via `SexidiumLinearFolderNames` (default `region`); `world` is the parent dir name (`.../<world>/<type>`) |
| `TOTALS` row | `TOTALS: read=%d (avg %d us) write=%d (avg %d us) flush=%d (avg %d us) load=%d filesFlushed=%d failures=%d folders=%d` (avgs are `totalMicros/total`, `0` when `0`) | Folder-wide aggregation across `region/`, `poi/`, `entities/`; `folders` is the snapshot map size |
| `dirtyDepth` | Per-folder row only (not in `TOTALS`) | Coordinator `dirty` set size under lock (pending flush depth) |
| `failures` / `filesFlushed` | Both row and `TOTALS` | `failures` counts `flushOne` retries; `filesFlushed` counts only `ok` flushes (failures tighten it; clean-no-op flushes record nothing via `didIo`) |

- Event contract: `org.bukkit.event.world.LinearRegionFlushCompletedEvent` is
  **ASYNC** (`super(true)`, fired OFF IO threads via the async scheduler,
  Folia-safe: never on the Moonrise IO thread). Flush-granularity: once per
  coordinator `flushDirty()` that attempted `>=1` file (clean-no-op flushes
  fire nothing). Carries `worldName`/`folderType` (`region|poi|entities`) plus
  post-flush `totals` snapshot. Listeners run async and **MUST NOT** touch
  world state directly; schedule back via the region scheduler if needed.
  Sample (5 lines, log-only):

```java
@EventHandler
public void onLinearFlush(LinearRegionFlushCompletedEvent e) {
    // Async: do not touch world state here; schedule back if needed.
    getLogger().info(e.getWorldName() + "[" + e.getFolderType() + "] flushed=" + e.getFilesFlushed());
}
```

- Troubleshooting: no rows but `.linear` exists → check the Paper-side save-path
  wiring (`SexidiumLinearFlushBridge#notifyFlush(Plugin,String,long,long)`
  ships **NO** call site in the patch; integrator must wire it after
  `LinearFlushCoordinator.flushDirty()` in world save — unwired bridges mean
  the command still works (pull-only) but the event never fires); event never
  fires on idle → **expected** (clean-no-ops fire nothing); `folderType`
  shows `region` for `poi/`/`entities/` → check the absolute folder-path suffix
  (`SexidiumLinearFolderNames` inference); permission denied → grant OP or
  `sexidium.command.linearstats`.

## 4. Known limitations (do NOT represent otherwise)

1. **Hot-read/write p99 unmeasured.** No live timings/spark comparison has been
   run on this build. Judge the rollout on warm-server p99 (§3 baselines), NOT
   on cold-start bars (page-cache misses / ZSTD warmup mislead).
2. **Symlink guard never fired live.** Covered by `BrokenSymlinkGuardTest`
   (fixtures + flag×format matrix) only; no live halt test has been run. The
   first live fire WILL halt the server — treat it as a drill, not an outage.
3. **Single-node scope; no shared-storage testing.** Local per-node disks only.
   NFS/shared-storage, multi-node same-dir, and cold-tier archiver behaviour
   are untested here (the cold-tier archiver death caveat from other tracks is
   N/A — there is no archiver in this release; the equivalent caution is: do
   not run two nodes against one world dir).
4. **Flush knobs are inert.** `flush-frequency` / `flush-max-threads` are
   declared and validated but nothing reads them yet (no scheduler/pool wiring
   in this release). Tuning them is a silent no-op. Additionally,
   `flush-frequency < 1` fails boot instead of falling back (constraint fires
   before `@PostProcess`) — keep it ≥ 1.
5. **Rollback rung B needs the operator's stock jar.** `rollback.sh` defaults
   `--stock-jar` to the placeholder `/opt/sexidium/stock/folia-paperclip-stock-26.1.2.jar`;
   rung B aborts with instructions until you point it at the real stock jar.
   Rung A needs no extra jar.
6. **Converter edge cases:** zero-byte region files are skipped (`skipped-empty`);
   Anvil-side oversize chunks re-emit as `.mcc` sidecars on `linear2mca`
   (carried in the manifest `sidecars` field) — verify `total diffs=0` before
   trusting any converted tree.
