# Loop 2 Report — Folia 26.1.2 Linear port (integrated, jar built)

Target: Folia fork `ver/26.1.x` @ `62dc0f2` (mc 26.1.2 STABLE), all work under
`/tmp/sexidium-folia`, sexidium repo untouched.

## What shipped (fork checkout)

- Vanilla parity proven first: full `./gradlew build` SUCCESS (~7 min, Java 25).
- New NMS code `net.sexidi`+`um`: `LinearRegionFile` (Xymb v2 header/footer,
  LZ4 hot path, zstd flush + checksum, atomic tmp+force+move; two ReentrantLocks,
  never held across IO; direct buffers), `LinearDirectStreams`,
  `AbstractRegionFile` + `AbstractRegionFileFactory` (dual-read dispatch),
  `RegionFileFormat` (storage enum), `LinearFlushCoordinator` (per-folder bounded
  dirty-set, zero threads — Moonrise owns IO), `ZstdChunkCodec` (direct-only,
  levels hot-1/flush-3/archive-6).
- Modified: `RegionFileStorage` (widened cache, dual-read probe `.mca`-first,
  flusher hooks, symlink guard), `RegionFile` (implements interface),
  `SimpleRegionStorage`, `IOWorker`, `ChunkMap`, `ServerChunkCache`,
  `ServerLevel`, `PoiManager`, `EntityDataController`, `RegionStorageUpgrader`
  (spaceless `(mca|linear)` REGEX + dual filter), `FileToUpgrade`,
  `MoonriseRegionFileIO`, `ChunkSystem*` seams.
- Config: `region-format.format` (ANVIL default, unknown→SEVERE+fallback),
  `linear.compression-level` (default 1, clamp 1–22), `linear.flush-max-threads`,
  `linear.crash-on-broken-symlink` (default true), global `flush-frequency`.
- Deps: `zstd-jni:1.5.6-8` added; lz4 via vanilla/mache (single copy, no duplicate).
- Durable patches: `0008` (paper config), `0009` (NMS port), `0010` (SUM deltas).
- Kaiiju B1–B3 fixed, not ported (`&&` predicate, enum identity, spaceless REGEX).

## Test information

| Suite | Result |
|---|---|
| Fork build `./gradlew build` + `createPaperclipJar` | SUCCESS — `folia-paperclip-26.1.2.local-SNAPSHOT.jar` (60.5 MB), ANVIL-default dual-read, `net/sexidium/*` verified inside |
| `BrokenSymlinkGuardTest` | 6/6 pass |
| `RegionStorageUpgraderScanTest` | 29/29 pass |
| `RegionFileCoordinatesTest` | 16/26 (10 accept-path failures environmental: `ChunkPos.<clinit>` needs server bootstrap — carry-over D1) |
| A8 converter round-trip (fixtures, 107 files, 109,568 slots) | 0 diffs |
| A9 harness (manifest + opacity gate + procedure + checklist) | delivered, unexecuted |

## Carry-over defects (Loop 3 owners)

D1 bootstrap harness for accept-tests; D3/D5 flusher policy (`flushRegionsOnSave`, MAX_DIRTY=512);
D4 `--recreate` upgrader still writes ANVIL; D6 clean-`applyAllPatches` proof pending;
D7 two `RegionFileFormat` enums need single mapping point.

## Loop 3 input

L3-1 clean-checkout apply proof (D6); L3-2 converter/upgrade integration incl.
`--forceWrite` reversibility (D4); L3-3 bootstrap harness + round-trip tests (D1);
L3-4 flusher policy (D3/D5, MAX_DIRTY validation); L3-5 dual-read soak prep
(one LINEAR world, hot-p99 gates, rollback drill); L3-6 rebase checklist.
