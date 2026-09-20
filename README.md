# folia-linear

Folia 26.1.2 fork with **native Linear region compression**: ~60% smaller live
worlds, dual-read with vanilla Anvil, ANVIL-default per-world opt-in.

![build](https://github.com/Ashu11-A/folia-linear/actions/workflows/build.yml/badge.svg)

## What / why

Vanilla Anvil (`.mca`) compresses every chunk individually with zlib and pads to
4 KiB sectors — on real SMP data that wastes roughly half the disk. This fork
adds the [Linear region format](https://github.com/xymb-endcrystalme/LinearRegionFileFormatTools)
(LZ4-hot path, whole-region zstd flush, checksums, atomic saves) directly into
Folia's chunk I/O, following the proven [Kaiiju](https://github.com/KaiijuMC/Kaiiju)
polyglot architecture — with Kaiiju's three known bugs fixed, never ported.

Measured on real SMP-like data (129 MB): **129 MB → 52 MB (59.6% saved)**,
identical boot/save walls, zero chunk diffs across 39k+ audited chunks,
9058 fork tests green.

Live SMP rollout (2026-09-19, ~3.05M chunks): **24.99 GiB → 16.57 GiB
(8.42 GiB, 33.7% saved)** — per-dimension breakdown and method in
`docs/folia-linear-savings-evidence.md`.

## Status

Pilot-ready, ANVIL-default. Rollback is a config flip (dual-read preserves
`.linear`) or `linear2mca` + stock jar. See `docs/folia-linear-program-report.md`.

## Quick start

```bash
# 1. Base (pinned) + this supplement
git clone --branch ver/26.1.x --single-branch https://github.com/PaperMC/Folia.git folia
cp folia-linear/patches/minecraft-*.patch folia/folia-server/minecraft-patches/features/
cp folia-linear/patches/paper-*.patch    folia/folia-server/paper-patches/features/
cp folia-linear/tests/*.java folia/folia-server/src/test/java/net/sexidium/
python3 folia-linear/scripts/apply-deps-hunk.py folia/folia-server/build.gradle.kts.patch
cp folia-linear/tests/*.java folia/folia-server/src/test/java/net/sexidium/

# 2. Build (Java 25)
cd folia && ./gradlew applyAllPatches build folia-server:createPaperclipJar
# -> folia-server/build/libs/folia-paperclip-26.1.2-*.jar

# 3. Opt a world in (default stays ANVIL): paper-world.yml
# region-format:
#   format: LINEAR
```

## Contributing: preflight before push

CI builds take ~10 minutes — don't spend them on staging bugs. Every change
must pass the local mirror first (seconds, same checks as the CI preflight job):

```bash
scripts/preflight.sh            # inventory + hunk determinism + workflow self-checks
scripts/preflight.sh --compile  # + fork compileJava (needs /tmp/sexidium-folia + network)
scripts/preflight.sh --tests    # + Linear suites green
```

Rule: push only on preflight green. The CI `preflight` job enforces the same
gates; the `build` job (full build + smokes + release attach) runs only after.

## Layout

- `patches/` — the fork: 0008/0009 paper config + tests, 0009/0010/0011 NMS
  Linear core + dispatch + guards; `scripts/apply-deps-hunk.py` wires the
  test tree + zstd dep into Folia's patch file (paperweight hunk convention,
  verified byte-identical to the proven build).
- `tests/` — tests not already inside the patches (round-trip + NMS suite wiring).
- `release/` — `rollback.sh` (rungs A/B/FORWARD with backup gates),
  operator notes, config templates.
- `docs/` — per-loop engineering reports (research → validation), plus
  `docs/folia-linear-savings-evidence.md` (live SMP numbers).
- `.github/workflows/` — CI: pinned-base clone, patch apply, build, Linear
  suites, boot smoke, release asset.

## Compatibility

- Plugins: untouched API surface (verified: Sexidium plugin enables cleanly).
  Anything opening `.mca` bytes directly will not see `.linear` contents.
- Vanilla/stock Folia cannot read `.linear` — exit via `linear2mca` converter
  + `--forceUpgrade --recreateRegionFiles` back to deflate (procedure in
  `release/OPERATOR-NOTES.md`).
- Geyser/Bedrock unaffected (chunk packets are vanilla).

## License

GPL-3.0, matching Paper/Folia/Kaiiju lineage. Patches derived from
[LinearPaper](https://github.com/xymb-endcrystalme/LinearPaper) (format),
[Kaiiju](https://github.com/KaiijuMC/Kaiiju) (polyglot architecture),
[paper-zstd](https://github.com/UltraVanilla/paper-zstd) (codec constraints),
and Spottedleaf's [SectorTool](https://github.com/PaperMC/SectorTool) (spec
reference) — see `docs/` for full attribution and trade notes.
