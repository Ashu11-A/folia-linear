# Operator notes

For whoever is holding the pager during a rollout. Keep `rollback.sh` and a
verified backup within reach before touching any flag.

## 1. Posture

- Every world starts on `region-format.format: LINEAR`. New writes go to
  `.linear`; readers probe both `.mca` and `.linear`, so pre-existing Anvil
  data keeps serving after the flip.
- Worlds that do not benefit can be pinned back to `ANVIL` per world. A mixed
  deployment inside one process is the supported end state, not a degraded one.
- The switch is per storage folder. Chunks and POI go through `ChunkMap`,
  entities through `EntityDataController`, and the dual-read probe covers both.
- `compression-level` defaults to `6`. The keep-it-at-1 soak gate is rescinded;
   new worlds ship at 6, and changing it later is a config flip with no
  conversion needed.
- `crash-on-broken-symlink` defaults to `true`. A broken `.linear` symlink halts
  the server by design, because continuing would regenerate chunks. Resolve
  symlinks before flipping anything.

Key reference: [../docs/configuration.md](../docs/configuration.md).

## 2. Opt-out procedure (LINEAR is the default)

1. **Backup, quiesced.** Stop the server or quiesce the world, then snapshot
   `region/`, `poi/` and `entities/` for the target world. Record it:
   `date -u +%FT%TZ > /backup/<world>/BACKUP_VERIFIED`. `rollback.sh` refuses to
   run without that marker.
2. **Health check.** No zero-byte `r.*.mca` files, and no broken symlinks:
   `find <world>/region <world>/poi <world>/entities -xtype l` must be empty.
3. **Baseline.** `du -sb region poi entities`, plus counts of `*.mca` against
   `*.linear`.
4. **Pin back at most one world.** Low-risk first, never spawn, never all
   worlds at once. Set `region-format.format: ANVIL` in that world's
   `paper-world.yml` only. Template: the per-world `ANVIL` override block in
   `region-format.yml` in this directory.
5. **Restart** and watch the log, section 3. Soak at least one full save cycle
   and one restart. Linear buffers flush on cadence, and the restart proves the
   files reopen.
6. **Repeat** one world at a time if more worlds need pinning, highest-churn
   worlds last.

## 3. Monitoring

### 3a. Proof that Linear I/O is happening

| Signal | Check | Why it proves it |
|---|---|---|
| New `r.X.Z.linear` files growing on writes | `ls <world>/region/*.linear \| wc -l` and `du -sb` after a save cycle and a restart | Writer dispatch routes through `extensionFor(format)`. Stock never emits that extension |
| Linear superblock on disk | `head -c 8 <file>.linear \| od -A x -t x1z` starts with `c3 ff 13 18 3c ca 9d 9a`; the trailer repeats the same eight bytes | On-disk proof independent of the logs. Check head and tail |
| Deferred flush behaviour | `ls -l --time-style=full-iso` across a save cycle: `.linear` mtimes advance on the save cadence, not on every edit | Matches the `LinearFlushCoordinator` design: dirty-tracked, `flushDirty()` on world save, no per-edit fsync storm |
| Offline chunk-set equality after conversion | `convert.py verify <tree-a> <tree-b>` reports `total diffs=0` | Payload-level proof that the converter path preserves chunks |

### 3b. Config fallback lines

The world boots, but not as intended. Fix the YAML.

- `[region-format] Unknown region format, expected ANVIL or LINEAR. Falling back to ANVIL.`
  The `format:` value is misspelled or wrong case, for example lowercase
  `linear`. The world is on Anvil despite the intent.
- `[region-format] linear.compression-level must be 1-22, got <v>. Falling back to 6.`
   Out-of-range level, running at 6.
- `[region-format] linear.flush-frequency must be >= 1, got <v>. Falling back to 10.`
  Frequency below 1. File stays tracked for the next save, see section 4.

### 3c. Lines that need action

| Line | Meaning | Action |
|---|---|---|
| `Linear region file <path> is a broken symbolic link, crashing to prevent data loss` | Symlink guard fired, the server halted | Resolve or replace the symlink from backup. Setting the flag to `false` boots for forensics; fix it properly afterwards |
| `Failed to flush linear region file for folder <dir>, will retry on next save` | A deferred flush failed. The file stays dirty and is retried next save | Check disk space, inodes and permissions on that directory. If it repeats every save, stop and roll back to rung A |
| `Linear region files cannot be recalculated, regenerating chunk <pos>` | Header mismatch in a `.linear` file. The chunk is regenerated, so its contents are lost | Note the coordinates and restore that region file from backup if the chunk matters |
| `Attempting to read chunk data at <pos> but got chunk data for <other> instead!` | Chunk or header skew, either format | Same as stock: let recalculation run. Persistent storms mean restore from backup |
| `Can't recalculate regionfile header, regenerating chunk <pos>` | Unrecoverable header, either format | Restore the region file from backup |
| `Chunk at (<x>,<z>) in regionfile '<name>' exceeds max size of <n>MiB, it has been deleted from disk` | Oversized chunk deleted, stock behaviour preserved | Occasional hits are expected on corrupt or oversized chunks. Frequent ones mean investigating the generator or a plugin |
| `MCC-AUDIT: <n> .mcc sidecar(s) ... SKIPPED` (converter) | Anvil-side oversized sidecars present, skipped loudly | Carry the sidecars alongside any manual copy. The Linear write path has no `.mcc` handling |
| `ERROR converting <path>: ...` (converter) | Per-file conversion failure | The live tree is untouched. Fix the file, usually a zero-byte one, and re-run |

### 3d. `linearstats`

- `/linearstats`, no arguments. Permission `linear.command.linearstats`, OP by
  default.
- `linearstats: no Linear folders tracked (no linear I/O yet).` on an
  Anvil-only node is expected, not a fault.
- Without the permission the sender gets a denial message and no rows.

Field meanings, the flush event contract and troubleshooting are in
[../docs/observability.md](../docs/observability.md).

## 4. Known limitations

Do not represent these as covered.

- **Hot read and write p99 are unmeasured.** No live timing or spark
  comparison has been run on this build. Judge the rollout on warm-server p99,
  not on cold-start numbers, which page-cache misses and zstd warmup distort.
- **The symlink guard has never fired live.** Static coverage only
  (`BrokenSymlinkGuardTest`, fixtures plus a flag-by-format matrix). The first
  live fire will halt the server. Treat it as a drill, not an outage.
- **Single node, local disk.** NFS, shared storage and two nodes against one
  world directory are untested. Do not run two nodes against one world
  directory.
- **The flush knobs are live, except batch logging.** `flush-frequency`
  (age-based flush), `flush-max-threads` (shared flush pool),
  `compression-workers` and `long-distance-matching` (zstd tuning) are read;
  only `log-flush-batches` remains inert (false = warn-only). Details in
  `docs/configuration.md`.
- **Rung B needs your own stock jar.** `rollback.sh` defaults `--stock-jar` to
  a placeholder path and aborts with instructions until you point it at a real
  one. Rung A needs no extra jar.
- **Converter edge cases.** Zero-byte region files are skipped. Anvil-side
  oversized chunks re-emit as `.mcc` sidecars on `linear2mca`, listed in the
  manifest `sidecars` field. Confirm `total diffs=0` before trusting any
  converted tree.

Full list: [../docs/limitations.md](../docs/limitations.md).

## 5. Async periodic drain

- Periodic drains (`flushDirtyAsync(false)` from unload/autosave paths)
  submit to the shared `linear-flush-*` pool and return without
  joining; the tick thread never blocks on file rewrites.
- Crash-loss window: up to one `flush-frequency` window (default 10 s:
  ~10 s of writes per file plus the single in-flight task).
- Clean shutdown is zero-loss: stop paths (`evictAll`, forced
  `flushAllDirty(true)`) remain synchronous joining barriers.
- On stop the pool uses `shutdown()` (never `shutdownNow()`) with a
  30 s await; in-flight tasks complete a torn write rather than
  being interrupted mid-image-rewrite.
