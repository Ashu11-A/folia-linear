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
