# v1.2.0 patch modules (versions/26.1.x/patches/)

Consolidation of the 18 v1.1.0 patches into 7 base patches (planned as v1.1.1, released as v1.2.0 with the B/F modules below).
Build tooling globs `*.patch` only, so this `.md` file is never staged
as a patch (see `scripts/build.sh` lines 95-96, `scripts/preflight.sh` §3).

Hunk counts verified post-assembly via `grep -c '^@@'`:
0009=67, 0010=27, 0011=7, 0012=12, 0013=4, paper-0008=7, paper-0009=7.

## 1. Module table

| Module | New patch | Source old patches (folded/superseded) | Notes |
|--------|-----------|----------------------------------------|-------|
| M1 core-format | `minecraft-0009-Linear-region-format.patch` | old `0009` + old `0010` + old `0011` | Folds: Moonrise `@@-1273` (0009 unconditional-flush superseded by 0011 batching), field/ctor folds, `ServerChunkCache`/`ServerLevel` supersedes (ANVIL,1 / ternary DIE → `fromConfig` mapping). Post-audit fixes included: restored `moonrise$write` pair (`ChunkSystemChunkBuffer @@-8`, `RegionFile @@-908`), fixed Moonrise `@@-1273` header + cascade. See staging `mod-core/hunk-origin-map.md` AUDIT-FIX addendum. |
| M3a observability | `minecraft-0010-Linear-region-observability.patch` | old `0012` + old `0015` | 6 coordinator + 15 region-file + 1 new-file (`LinearRegionTimings`, 98 lines: 81 + 11 + 6) + 5 storage hunks. Post-audit L3-B4 context fix included. `L3-B4 (Q4)` storage context kept byte-identical by design. |
| M2a flush-unlock | `minecraft-0011-Linear-flush-unlock.patch` | old `0013` + old `0014` | 7 hunks, `RegionFileStorage.java` only. U1–U6 = old-0014, U7 = old-0013 (`@@-623→@@-641`, +18 net). `L2-A4` lines kept byte-identical. Post-audit shared-context substitutions applied (see `mod-flush/shared-context-edits.json` `edits` array). |
| M2b flush-coordinator | `minecraft-0012-Linear-flush-coordinator.patch` | old `0016` + old `0017` + old `0019` + old `0020` | 12 hunks (9 `LinearFlushCoordinator.java` + 3 `LinearRegionFile.java`). C7 final state = 0019 try/finally + `notifyFlushSync`; 0016 serial dispatch superseded (42 minus lines dropped). `minecraft-0019:` bridge-comment tag kept intentionally (spec: drop only `(PATCH8, agent 27)`). Coordinator file carries no `index` line (synthesized H1, legal for `git apply`/`am`). |
| M3b zstd | `minecraft-0013-Linear-zstd-tuning.patch` | old `0018` | 4 hunks, all `LinearRegionFile.java`. Setters only before first write; defaults 0 = inert; reader `setLongMax(27)` before first read. |
| M4 config | `paper-0008-Linear-config.patch` | old `paper-0008` + old `paper-0009` + old `paper-0012` | 7 hunks. H1 = p0008 `@@-343` minus `@Constraints.Min(1)` (deleted by p0009) plus p0012 inert keys (`compressionWorkers`/`longDistanceMatching`/`logFlushBatches` + `<0` clamps). H7 = p0009 OR-gate. `RegionFileCoordinatesTest` (106 lines) created by p0008 and deleted 1:1 by p0009 → net absent. |
| M3c linearstats | `paper-0009-Linear-linearstats.patch` | old `paper-0010` + old `paper-0011` + old `paper-0013` | 7 hunks (1 modify + 6 new files). **API fix (+15 lines in `LinearStats.java`):** record gains 5 components + 5 `@param` lines + 5 mapping passthroughs so the panel/API exposes the minecraft-0015 measurement fields (`rawBytes`, `compressedBytes`, `flushP50Micros`, `flushP99Micros`, `millisSinceLastFlush`). This is the ONE intentional behavior delta; everything else is comment-only. |

## 2. Full old → new number map

### minecraft (old 12 → new 5)

| Old patch file (v1.1.0) | Disposition → new patch |
|-------------------------|-------------------------|
| `minecraft-0009-Linear-region-format-A3-A4-B2.patch` | → new `minecraft-0009-Linear-region-format.patch` (base + folds) |
| `minecraft-0010-Linear-SUM-reconciliation-crash-flag-guard.patch` | → new `minecraft-0009-Linear-region-format.patch` (crash-flag folds; phantom `build.gradle.kts.patch` claim in commit body emitted nothing — no such diff exists) |
| `minecraft-0011-Linear-Loop3-integration-B2-B3-B4-B5.patch` | → new `minecraft-0009-Linear-region-format.patch` (Main/upgrader/storage/`fromConfig` folds; Moonrise batching half) |
| `minecraft-0012-Linear-region-timing.patch` | → new `minecraft-0010-Linear-region-observability.patch` (timing base) |
| `minecraft-0013-Linear-unlock-flush-batch.patch` | → new `minecraft-0011-Linear-flush-unlock.patch` (U7 close/flush) |
| `minecraft-0014-Linear-eviction-close-outside-monitor.patch` | → new `minecraft-0011-Linear-flush-unlock.patch` (U1–U6 unlock) |
| `minecraft-0015-Linear-measurement-counters.patch` | → new `minecraft-0010-Linear-region-observability.patch` (counters appended; `LinearRegionTimings` 12-arg → 17-arg record) |
| `minecraft-0016-Linear-shared-flush-pool.patch` | → new `minecraft-0012-Linear-flush-coordinator.patch` (pool fields/methods; dispatch superseded by 0019) |
| `minecraft-0017-Linear-age-based-flush.patch` | → new `minecraft-0012-Linear-flush-coordinator.patch` (age-gate, dirty-order, requeue, freq methods) |
| `minecraft-0018-Linear-zstd-workers-ldm.patch` | → new `minecraft-0013-Linear-zstd-tuning.patch` (verbatim + scrubs) |
| `minecraft-0019-Linear-flush-bridge-call-site.patch` | → new `minecraft-0012-Linear-flush-coordinator.patch` (C7 bridge final state) |
| `minecraft-0020-Linear-opportunistic-age-flush.patch` | → new `minecraft-0012-Linear-flush-coordinator.patch` (age/durability extension, cache fields, mark-head/body) |

### paper (old 6 → new 2)

| Old patch file (v1.1.0) | Disposition → new patch |
|-------------------------|-------------------------|
| `paper-0008-Linear-config-dual-read-tests-A7-A5.patch` | → new `paper-0008-Linear-config.patch` (base) |
| `paper-0009-Linear-Loop-3-K4-B5.patch` | → new `paper-0008-Linear-config.patch` (`Min(1)` deletion, OR-gate, `RegionFileCoordinatesTest` 1:1 create/delete) |
| `paper-0012-Linear-Loop-3-inert-config-keys.patch` | → new `paper-0008-Linear-config.patch` (inert keys + clamps) |
| `paper-0010-Linear-linearstats-command-hooks.patch` | → new `paper-0009-Linear-linearstats.patch` (command/bridge/folder/events base) |
| `paper-0011-Linear-linearstats-api-delegate.patch` | → new `paper-0009-Linear-linearstats.patch` (paper event + `LinearStats` base) |
| `paper-0013-Linear-linearstats-panel-bridge.patch` | → new `paper-0009-Linear-linearstats.patch` (panel extensions on the two p0010-created files) |

## 3. Apply order

`scripts/build.sh` copies `minecraft-*.patch` and `paper-*.patch` into the
Folia feature dirs; Paperweight applies each family in lexicographic
(filename-sort) order. The new numbering is chosen so sort order = apply order:

- minecraft: `0009` (format) → `0010` (observability) → `0011` (flush-unlock) → `0012` (flush-coordinator) → `0013` (zstd-tuning)
- paper: `0008` (config) → `0009` (linearstats)

Cross-stack file overlap is NONE (minecraft = `net/...` tree, paper =
`src/...` tree; verified in staging). Runtime dependency only: the paper
panel + `LinearStats` read the minecraft-0015 measurement snapshot fields,
and the minecraft-0019 bridge overload is wired by coordinator C7.

Shared-context note: unlock (0011) and coordinator (0012) context lines were
re-pointed at the scrubbed post-0009/post-0010 tree (e.g. `Linear L1-TIMING:` →
`Linear:`, `A3 contract` → `region-file contract`, `(A2)` dropped,
`L2-A4:` dropped, `L3-B4 (Q4)` → `Linear -` in 0009-owned lines only).
See staging `mod-flush/shared-context-edits.json` `edits` array and
`mod-core/hunk-origin-map.md` shared-context dependents section. The two
`L3-B4 (Q4)` lines owned by 0010 are pinned byte-identical (not scrubbed).

## 4. Known intentional behavior delta

- `LinearStats` (paper-0009) gains 5 measurement fields
  (`rawBytes`, `compressedBytes`, `flushP50Micros`, `flushP99Micros`,
  `millisSinceLastFlush`) with params + mapping passthroughs, closing the
  API gap against the minecraft-0015 snapshot. Panel reads them.
- Everything else in the base consolidation is comment-only vs v1.1.0 (provenance-label
  scrubs, 1:1 rewrites, renumbered headers, folds with no semantic change).
  Superseded hunks (0009 ANVIL,1 / 0010 ternary DIE / 0009 unconditional
  flush / 0016 serial dispatch) resolve newer-wins by construction; the kept
  text is the v1.1.0 tip behavior, not a change.

## 5. B-modules (v1.1.1 follow-ups: defaults flip, startup conversion, pipeline)

Ranges pre-assigned, no renumbering: minecraft `0014`/`0015`/`0016`,
paper `0010`/`0011`. Sort order = apply order within each family.

| Module | New patch | Prereq | Notes |
|--------|-----------|--------|-------|
| B1 defaults | `minecraft-0014-Linear-default-format-9.patch` | after `0013` | Flips shipped defaults ANVIL→LINEAR, level 1→9. New behavior (was opt-in, now opt-out). |
| B2 trigger | `minecraft-0015-Linear-startup-conversion.patch` | after `0014` | Startup conversion trigger. New behavior. NMS-tree test: `LinearStartupConversionTest.java` in `versions/26.1.x/tests/`. |
| B3 pipeline | `minecraft-0016-Linear-conversion-pipeline.patch` | after `0015` | Conversion pipeline. New behavior. NMS-tree test: `LinearConversionPipelineTest.java` in `versions/26.1.x/tests/`. |
| B1 defaults | `paper-0010-Linear-default-format-9.patch` | after `0009` | Paper-side defaults flip. The `LinearDefaultFormatTest` canonical copy rides INSIDE this patch (Paper test tree); no separate copy in `versions/tests/` because it hard-imports `io.papermc.paper.configuration.WorldConfiguration`. |
| B2 trigger | `paper-0011-Linear-startup-conversion.patch` | after `0010` | Paper-side startup conversion wiring. |

Doc map: value source of truth is B1's
`/tmp/opencode/v111/staging/b1-defaults/DOC-UPDATES.md` (LINEAR / level 9);
file-path application is E3's `*.edit.md` scripts (this repo: `README.md`,
`docs/configuration.md`, `release/OPERATOR-NOTES.md`, `release/RELEASE.md`)
plus the `migration-map.md` disposition table. Values and paths agreed, no
contradiction found.

## 6. Save drain (finding F fix, v1.1.1 release-blocker)

Root cause: vanilla `RegionFileStorage` instances are never flushed or closed
by the Folia/Moonrise runtime (Moonrise owns I/O lifecycle through its own
classes; `IOWorker.synchronize(true)` and storage `close()` have no runtime
callers). The coordinator dirty set therefore drained only via bound
pressure. ANVIL is unaffected (sector write-through needs no drain); LINEAR
buffers in RAM, so fresh worlds persisted nothing on clean stop (proven:
w=1587/f=0/dirty=12 via `/linearstats`, zero files after orderly `stop`).

| Module | New patch | Prereq | Notes |
|--------|-----------|--------|-------|
| F drain | `minecraft-0017-Linear-save-drain.patch` | after `0016` | New `LinearFlushCoordinator.flushAllDirty(force)` + `evictAll()`; hooks in `ServerChunkCache.save` (forced iff flushStorage, else age-gated) and `ServerLevel.close` (evictAll). NMS-tree test: `LinearSaveDrainTest.java` in `versions/26.1.x/tests/`. |

### 0017-v2 (finding F, revised after live proof)
v1 additionally hooked `ServerChunkCache.save` + `ServerLevel.close`, but
D-build-final proved both unreachable on Folia paths (autosave bypasses
`chunkSource.save`; stop uses `close=true` which skips it; `ServerLevel.close`
never runs). v2 hooks the paths that demonstrably execute: `MinecraftServer.
saveAllChunks(..., close)` → `evictAll()` when close (stop drain, runs after
the per-level loop); `ServerLevel.saveIncrementally` → age-gated
`flushAllDirty(false)` every autosave cycle (crash-durability bound). Keeps
the v1 hooks as harmless backups. Proof required: runtime-durability smoke
(fresh LINEAR world, graceful stop → `.linear` files exist).

### 0017-v3 (finding F, revised after live proof)
v1 hooks (`ServerChunkCache.save`, `ServerLevel.close`) plus v2 hooks
(`saveAllChunks` close-branch, `saveIncrementally`) all proved unreachable or
ineffective at runtime (Folia shutdown runs via `RegionShutdownThread`;
autosave bypasses vanilla-named save methods; flush stayed 0 over 7+ min).
v3 keeps them as harmless backups and adds the two demonstrably-executed
choke points: `ChunkMap.processUnloads` tail → age-gated `flushAllDirty(false)`
every unload pass (autosave/crash bound), and `RegionShutdownThread.
saveRegionChunks` → `evictAll()` after Moonrise close per region (stop drain).
Proof required: runtime-durability smoke (fresh LINEAR world, graceful stop
→ `.linear` files exist).

### 0017-v4 (finding F, final: proven empty-regions + probe-verified call sites)
v3 hook inside per-region `saveRegionChunks` proved dead: the method completes
but `computeForAllRegionsUnsynchronised` yields zero regions post-halt (its
loop body never runs; only the caller's log lines appear). v4 moves the stop
drain to `RegionShutdownThread.run()` right after `stopServer()`, while
regions/coordinators are populated. Six files, +69/-0, no probes shipped.
