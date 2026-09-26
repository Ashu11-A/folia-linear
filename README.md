# folia-linear

Patch supplement that adds the [Linear region format](https://github.com/xymb-endcrystalme/LinearRegionFileFormatTools)
to Folia 26.1.2. Worlds write Linear (`.linear`) region, POI and entity files
by default; any world can be pinned back to Anvil (`.mca`) per world.

![test](https://github.com/Ashu11-A/folia-linear/actions/workflows/test.yml/badge.svg)
![build](https://github.com/Ashu11-A/folia-linear/actions/workflows/build.yml/badge.svg)

`LinearNmsTestSuite`: 79 tests green.

## How it works

- Anvil compresses every chunk on its own with zlib, then pads each one up to a
  4 KiB sector boundary. Both cost space.
- Linear keeps chunks LZ4-compressed in memory and writes the whole region as a
  single zstd blob on save: no per-chunk padding, and zstd sees 1024 chunks of
  similar data at once instead of one.
- Reads probe both extensions, so existing `.mca` files keep serving after the
  flip. New worlds convert automatically on first boot; explicit-ANVIL worlds
  are never touched.
- Architecture follows [Kaiiju](https://github.com/KaiijuMC/Kaiiju), with its
  three known bugs fixed rather than carried over (see
  [docs/architecture.md](docs/architecture.md)).

## Measured results

Stress sweep on a full SMP world (24.27 GiB as Anvil), 3 runs per level on the
fixed jar, plus SIGKILL durability rows. Raw rows and method:
`versions/26.1.x/bench/stress-1-22.csv`,
[docs/benchmarks.md](docs/benchmarks.md).

| Level | Size | Saved vs Anvil | Shutdown (grace 120 s) | Chunks lost |
|---|---|---|---|---|
| Anvil | 24.27 GiB | — (anchor) | — | — |
| 1 | 16.58 GiB | 31.7% | 70–75 s | 0 |
| 3 | 16.03 GiB | 33.9% | 66–84 s | 0 |
| 6 | 13.86 GiB | 42.9% | 71–74 s | 0 |
| 9 | 13.45 GiB | 44.6% | 69–74 s | 0 |
| 12 | 13.21 GiB | 45.6% | 120.9 s → SIGKILL | 2047 of 6144 |
| 15 † | 12.86 GiB | 47.0% | 121.0 s → SIGKILL | unknown |
| 22 †† | 11.04 GiB | ~54.5% | — | — |

Shutdown is SIGTERM-to-exit against a 120 s grace period; levels 1–9 shut down
gracefully on all 12 rc runs with zero chunks lost. 6 GiB container, 0 OOM
kills; tick p99 unmeasured.

† Level 15 ran on the pre-fix jar only (chunks-lost unknown).
†† Level 22 is from the offline rewrite, not the sweep (no shutdown coverage).

> **Do not use level 12 or above.** At 12 the server crossed the 120 s grace
> period and was SIGKilled mid-flush, losing 2047 chunks.

> **Recommended: compression level 6.** Tightest shutdown range of the sweep,
> 42.9% smaller than Anvil, and nowhere near any cliff. Level 9 is the shipped
> default.

Under SIGKILL mid-write the fixed jar loses ~55% of edited chunks. Ungraceful
kills still lose data — Linear is crash-safe, not crash-proof.

## Configuration

Two settings under `region-format`: which format a world writes, and how hard
zstd compresses on flush.

```yaml
# paper-world-defaults.yml (server default; per-world paper-world.yml overrides)
region-format:
  format: LINEAR            # LINEAR (default) or ANVIL; new writes only
  linear:
    compression-level: 9    # 1-22; default 9, recommended 6, 12+ unsafe
    crash-on-broken-symlink: true
```

```yaml
# paper-global.yml
region-format:
  linear:
    flush-frequency: 10     # seconds; age gate for deferred flush
    flush-max-threads: 1    # shared flush pool size; <=1 keeps serial
```

Changing the level is a config flip, not a migration: files are rewritten at
the new level as they are saved. Full reference:
[docs/configuration.md](docs/configuration.md). Comment-free template:
`release/region-format.yml`.

## Build

Requires Java 25 and ~25 GB free disk (~10 minutes on CI).

```bash
scripts/build.sh --mc 26.1.x   # one version
scripts/build.sh                # all versions
# -> versions/26.1.x/build/folia-paperclip-26.1.2-*.jar
```

Releases, patch conventions and the porting checklist:
[CONTRIBUTING.md](CONTRIBUTING.md).

## Operating

- **Opting a world out:** snapshot the world, set `format: ANVIL` in that
  world's config, restart, and soak through one save cycle plus one restart.
  Full procedure: [release/OPERATOR-NOTES.md](release/OPERATOR-NOTES.md).
- **Rolling back:** `release/rollback.sh` (flag flip, convert-back, re-opt-in)
  refuses to run without a verified backup. Details in the operator notes.
- **Monitoring:** `/linearstats` prints per-world I/O counters (permission
  `linear.command.linearstats`, OP by default);
  `LinearRegionFlushCompletedEvent` fires per flush for plugins. Proof of life:
  new `.linear` files after a save cycle, starting with bytes
  `c3 ff 13 18 3c ca 9d 9a`. Details in
  [docs/observability.md](docs/observability.md).

## Compatibility

- Plugin API is untouched. Anything that reads `.mca` bytes directly will not see
  chunks stored in `.linear` files.
- Stock Folia cannot read `.linear`. Leaving the fork means converting back first
  (rung B above).
- Geyser and Bedrock clients are unaffected, since chunk packets are vanilla.
- `.mcc` sidecars for oversized chunks exist on the Anvil side only. The Linear
  writer rejects an oversized payload instead of spilling it to a sidecar.

## License and credits

GPL-3.0, matching the Paper/Folia/Kaiiju lineage.

Full text: [LICENSE](LICENSE).

- [LinearRegionFileFormatTools](https://github.com/xymb-endcrystalme/LinearRegionFileFormatTools)
  and [LinearPaper](https://github.com/xymb-endcrystalme/LinearPaper) for the
  format and the reference implementation.
- [Kaiiju](https://github.com/KaiijuMC/Kaiiju) for the dual-format architecture.
- [paper-zstd](https://github.com/UltraVanilla/paper-zstd) for the codec
  constraints.
- Spottedleaf's [SectorTool](https://github.com/PaperMC/SectorTool) as spec
  reference, and the GC rules its review established for hot-path buffers.
