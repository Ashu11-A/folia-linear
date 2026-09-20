# Live SMP savings evidence — 2026-09-19

Production rollout on the Sexidium SMP (~3.05M chunks, Folia `ver/26.1.x`
@ `62dc0f2`, MC 26.1.2, Java 25): each dimension converted offline
(`mca2linear`), round-trip verified (`linear2mca` + `verify total diffs=0`),
overlaid beside `.mca`, then `.mca` deleted post-verification.

| Dim | ANVIL | LINEAR | Saved | % |
|---|---|---|---|---|
| Overworld | 22.44 GiB | 16.15 GiB | 6.29 GiB | 28.0% |
| Nether | 0.26 GiB | 0.15 GiB | 0.10 GiB | 40.5% |
| End | 2.29 GiB | 0.27 GiB | 2.02 GiB | 88.2% |
| **Total** | **24.99 GiB** | **16.57 GiB** | **8.42 GiB** | **33.7%** |

Method: `du -sb` per `region/entities/poi` before/after; file counts 8,381
`.mca` → 8,380 `.linear` (overworld 7,380/7,379, nether 117/117, end
884/884). One corrupt live region (`overworld/region/r.-24.11.mca`, slot 583
zlib error, deterministic) kept `.mca`-only; the server regenerates that
single chunk (stock parity). Per-world `format: LINEAR` in each dim's
`paper-world.yml`; defaults stay ANVIL.

Notes:

- Ratios vary by dimension: the sparse End compresses ~8x, the dense
  overworld ~1.4x. Prior fixture result for contrast: `128,961,741 →
  52,163,783 B (0.404, 59.6% saved)` on smp-like data
  (`docs/folia-linear-loop4-report.md` G6); soak worlds store ~30%
  (`docs/folia-linear-loop5-report.md`).
- Live jar: CI release asset `sexidium-folia-26.1.2.jar`
  (`082ccbfa…`, 60,511,732 B) — a different artifact from the local
  snapshot build (`3d4713a0…`, 60,509,601 B), hence the different sha.
- Post-delete, End and Nether each proved clean Linear-only reboots
  (`Done` ~10s, 0 `[region-format]` errors) before the overworld followed.
- Full procedure: `release/OPERATOR-NOTES.md`; rollback rungs A/B/FORWARD:
  `release/rollback.sh`.

## Compression level 1 vs 22 — 2026-09-20

Same SMP tree, rewritten offline at max level (`mca2linear -c 22`,
round-trip `linear2mca` + `verify total diffs=0` per dim/half, overlay
`*.linear` only). Region-file bytes (`du -sb` on `region/`):

| Dim | Level 1 | Level 22 | Saved | % |
|---|---|---|---|---|
| Overworld region | 17,339,006,898 B | 11,561,937,798 B | 5,777,069,100 B | 33.3% |
| Nether region | 165,375,247 B | 111,835,003 B | 53,540,244 B | 32.4% |
| End region | 291,280,114 B | 157,860,846 B | 133,419,268 B | 45.8% |
| **SMP total** | **17,795,662,259 B (16.57 GiB)** | **11,852,762,522 B (11.04 GiB)** | **5,942,899,737 B (5.54 GiB)** | **33.4%** |

vs original ANVIL (`26,833,329,824 B / 24.99 GiB`): **14,980,567,302 B
(13.95 GiB) saved = 55.8%**, all 8,380 `.linear` files at level 22
(superblock level byte audited), 1 `.mca` kept (`r.-24.11.mca`).

Notes:

- Cost of 22: `mca2linear -c 22` runs ~20 files/min/worker (vs ~10x
  faster at `-c 1`); overworld halves took ~40 min each on 8–10 workers.
  Live flush cost at 22 is unmeasured over a long soak — watch save-wall
  and p99 before calling 22 the default. Soak-at-1 stays the rule.
- Rollback 22 → 1 is a config flip (no rewrite: the on-disk level byte
  is informational, decode is level-independent).
- Soak: two clean boots at 22 (`Done` 9.9s / 10.1s, 0 errors),
  save-all flush clean, `status` green.
