# Benchmarks and measured results

Everything here was measured on this fork. Numbers that were never taken are
listed as not measured rather than estimated; see [limitations.md](limitations.md)
for the full list of open questions.

## Summary

| Measurement | Before | After | Saved |
|---|---|---|---|
| Fixture tree, SMP-like data | 128,961,741 B | 52,163,783 B | 59.6% |
| Live SMP, all dimensions, level 1 | 24.99 GiB | 16.57 GiB | 33.7% |
| Live SMP region files, level 1 to 22 | 16.57 GiB | 11.04 GiB | 33.4% |
| Live SMP, Anvil to level 22 | 24.99 GiB | 11.04 GiB | 55.8% |
| Soak world | Anvil baseline | ~30% of the bytes | ~70% |

Ratios depend heavily on what the world contains. Sparse dimensions compress
several times over; dense, heavily built overworlds are closer to 1.4x.

## Live SMP rollout, 2026-09-19

Sexidium SMP, roughly 3.05M chunks, Folia `ver/26.1.x` at `62dc0f2`, Minecraft
26.1.2, Java 25.

| Dimension | Anvil | Linear | Saved | % |
|---|---|---|---|---|
| Overworld | 22.44 GiB | 16.15 GiB | 6.29 GiB | 28.0% |
| Nether | 0.26 GiB | 0.15 GiB | 0.10 GiB | 40.5% |
| End | 2.29 GiB | 0.27 GiB | 2.02 GiB | 88.2% |
| **Total** | **24.99 GiB** | **16.57 GiB** | **8.42 GiB** | **33.7%** |

Method:

- Each dimension converted offline with `mca2linear`, then round-tripped back
  with `linear2mca` and checked with `verify`, which reported `total diffs=0`.
- The `.linear` tree was laid down beside the `.mca` tree, and the `.mca` files
  were deleted only after verification.
- Sizes are `du -sb` over `region/`, `entities/` and `poi/` before and after.
- File counts went 8,381 `.mca` to 8,380 `.linear`: overworld 7,380 to 7,379,
  nether 117 to 117, end 884 to 884.
- The one missing file is `overworld/region/r.-24.11.mca`, which has a
  deterministic zlib error in slot 583. It was left as `.mca`; the server
  regenerates that single chunk, which is stock behaviour.
- `format: LINEAR` was set per dimension in each world's `paper-world.yml`.
  Defaults stayed `ANVIL`.
- End and Nether each proved a clean Linear-only reboot (`Done` in about 10
  seconds, no `[region-format]` errors) before the overworld was converted.

## Compression level 1 against 22, 2026-09-20

Same tree, rewritten offline with `mca2linear -c 22`, round-tripped and verified
per dimension and per half. Region files only.

| Dimension | Level 1 | Level 22 | Saved | % |
|---|---|---|---|---|
| Overworld | 17,339,006,898 B | 11,561,937,798 B | 5,777,069,100 B | 33.3% |
| Nether | 165,375,247 B | 111,835,003 B | 53,540,244 B | 32.4% |
| End | 291,280,114 B | 157,860,846 B | 133,419,268 B | 45.8% |
| **Total** | **17,795,662,259 B** | **11,852,762,522 B** | **5,942,899,737 B** | **33.4%** |

Against the original Anvil total of 26,833,329,824 B (24.99 GiB), level 22
saves 14,980,567,302 B, which is 13.95 GiB or 55.8%.

All 8,380 files were confirmed at level 22 by auditing the header level byte.
The one corrupt region stayed `.mca`.

Cost:

- `mca2linear -c 22` managed about 20 files per minute per worker, roughly ten
  times slower than level 1. Each overworld half took around 40 minutes across
  8 to 10 workers.
- Two clean boots at level 22 (`Done` at 9.9 s and 10.1 s, no errors), a clean
  `save-all` flush, and a green `status`.
- The live flush cost at level 22 over a long soak has not been measured. Watch
  the save wall and tick p99 before making 22 a default. Soak new worlds at
  level 1.
- Going back from 22 to 1 is a config flip. No rewrite is needed, because the
  header level byte is informational and decoding is level-independent.

## Fixture validation

Run against a 129 MB SMP-like fixture tree on the release-candidate jar:

- Disk: 128,961,741 B to 52,163,783 B, a ratio of 0.404, 59.6% saved.
- Chunk equality: ~39,000 chunks audited across 25 `.mca` and 13 `.linear`
  files, zero failures.
- Three-cycle soak with no drift: 25 of 25 sha256 sums identical across cycles.
- Boot times across Anvil, mixed and Linear worlds: 5.1 s to 7.4 s, within noise
  of each other, no fork errors.
- Save parity: both formats completed within the same second.
- Deferred flush confirmed observationally. `.linear` files change on the save
  cadence, not on every edit.
- `linear2mca` on 74 files: no errors.
- Network unaffected: status JSON served, 44 ms and 0.7 ms pings, protocol 775.

## Paired soak

- Anvil and Linear load walls were indistinguishable: forceload, summon and fill
  all finished in roughly 0.2 to 0.4 s in both formats.
- The Linear world stored about 30% of the bytes of the Anvil one.
- One sample showed a 1.8 s longer shutdown flush on Linear. Single sample, not
  reproduced, treated as noise pending a repeat.

## Test suites

- 9058 tests green on the patched fork, 22 skipped, zero failures.
- 64 Linear-specific tests: 29 upgrader scan, 26 region-file coordinates, 6
  broken-symlink guard, 3 round-trip.
- Converter round-trip on fixtures: 107 files, 109,568 slots, zero diffs.
- Builds are deterministic. The same source produced a byte-identical
  60,509,601 B paperclip jar on separate runs.

## What is not measured

- Tick p99 with players connected, on either format. All timing above is from
  empty or scripted worlds.
- Live flush cost at high compression levels over a multi-day soak.
- Behaviour on shared or network storage. Everything here is local disk.

## Reproducing

- Sizes: `du -sb <world>/region <world>/poi <world>/entities` before and after.
- Chunk equality: `convert.py verify <tree-a> <tree-b>`, expect `total diffs=0`.
- Conversion: `convert.py mca2linear <src> <dst> -t <threads> -c <level>`.
- The converter is not part of this repository; see
  [limitations.md](limitations.md).
