# Limitations and open questions

What this release does not cover. Read it before a rollout, not after.

## Not measured

- **Tick p99 with players connected.** No live timing or spark comparison has
  been taken on this build, in either format. Judge a rollout on warm-server
  p99, not on cold-start numbers: page-cache misses and zstd warmup make the
  first minutes look worse than steady state.
- **Live flush cost at high compression levels.** Level 22 has clean boots and a
  clean `save-all` behind it, but no long soak. Level 9 is the shipped default;
  multi-day soak cost above it is still unmeasured.
- **Shutdown flush duration.** One paired sample showed Linear taking 1.8 s
  longer to shut down. Single sample, unconfirmed.

## Not exercised live

- **The broken-symlink guard has never fired on a real server.** It is covered
  by `BrokenSymlinkGuardTest` with fixtures and a flag-by-format matrix, which
  is static coverage only. The first live fire will halt the server, by design.
  Treat it as a drill.
- Vanilla symlink validation intercepts before the Linear guard in some paths,
  so the guard is format-scoped rather than universal.

## Scope

- **Single node, local disk only.** NFS, shared storage, two nodes against one
  world directory, and cold-tier archivers are all untested here. Do not run two
  nodes against the same world directory.
- There is no cold-tier archiver in this release, so archiver-related cautions
  from other work do not apply.

## Configuration wiring

- `region-format.linear.flush-frequency`, `region-format.linear.flush-max-threads`,
  `region-format.linear.compression-workers` and
  `region-format.linear.long-distance-matching` are declared, validated and
  wired: the flush pool, the age-based flusher and the zstd workers all read
  them (`flush-max-threads <= 1` stays serial, `compression-workers: 0` stays
  serial, LDM `0` stays off). Only `region-format.linear.log-flush-batches`
  is still a silent no-op (`false` = warn-only). New worlds ship `LINEAR` at
  level 9. See [configuration.md](configuration.md).

## Rollback

- Rung B needs a stock Folia jar that you supply. `rollback.sh` defaults
  `--stock-jar` to a placeholder path and aborts with instructions until you
  point it somewhere real. Rung A needs no extra jar.
- Every rung refuses to run without `--backup-dir` pointing at a snapshot that
  contains a `BACKUP_VERIFIED` marker and at least one `region/` tree.

## Converter

Two converters exist. Do not confuse them.

- **Built-in startup conversion** (in this repository, `minecraft-0015` +
  `minecraft-0016`): on boot, worlds whose active format resolves to LINEAR
  convert leftover `.mca` files through a convert → validate → delete pipeline
  (3 retries, protection halt on exhaustion). Explicit-ANVIL worlds never
  convert.
- **Offline tree converter** (`mca2linear`, `linear2mca`, `verify`): **not part
  of this repository**. The docs reference it because it produced the numbers
  in [benchmarks.md](benchmarks.md). The same applies to the
  release-candidate jar paths quoted in `release/RELEASE.md`: those are local
  build outputs, not repository contents.

Known converter behaviour:

- Zero-byte region files are skipped and reported as `skipped-empty`.
- Anvil-side oversized chunks re-emit as `.mcc` sidecars on `linear2mca`, listed
  in the manifest `sidecars` field. The Linear write path has no `.mcc`
  handling at all, so carry sidecars along with any manual copy.
- Always confirm `total diffs=0` before trusting a converted tree.
- A per-file failure prints `ERROR converting <path>: ...` and leaves the live
  tree untouched. Zero-byte files are the usual cause.

## Data-loss edges

- A header mismatch in a `.linear` file regenerates that chunk, which loses its
  contents. The log line is
  `Linear region files cannot be recalculated, regenerating chunk <pos>`.
- Chunks over 500 MiB are rejected rather than written to a sidecar.
- One region file on the live SMP (`r.-24.11.mca`) has a deterministic zlib
  error and cannot be converted. It stays Anvil and the server regenerates the
  affected chunk.

## Maintenance

- The fork has to be rebased on each upstream Folia release. The surfaces that
  break are listed in [architecture.md](architecture.md).
- A zstd dictionary phase was scoped and parked. `ZstdChunkCodec` stubs the
  provider API and ships no dictionary bytes.
