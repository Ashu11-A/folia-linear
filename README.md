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

## Status

Pilot-ready, ANVIL-default. Rollback is a config flip (dual-read preserves
`.linear`) or `linear2mca` + stock jar. See `docs/folia-linear-program-report.md`.

## Quick start

```bash
# 1. Base (pinned) + this supplement
git clone --branch ver/26.1.x --single-branch https://github.com/PaperMC/Folia.git folia
cp folia-linear/patches/minecraft-*.patch folia/folia-server/minecraft-patches/features/
cp folia-linear/patches/paper-*.patch    folia/folia-server/paper-patches/features/
git -C folia apply ../folia-linear/patches/deps-zstd.patch
cp folia-linear/tests/*.java folia/folia-server/src/test/java/net/sexidium/

# 2. Build (Java 25)
cd folia && ./gradlew applyAllPatches build folia-server:createPaperclipJar
# -> folia-server/build/libs/folia-paperclip-26.1.2-*.jar

# 3. Opt a world in (default stays ANVIL): paper-world.yml
# region-format:
#   format: LINEAR
```

## Layout

- `patches/` — the fork: 0008/0009 paper config + tests, 0009/0010/0011 NMS
  Linear core + dispatch + guards, `deps-zstd.patch` (zstd-jni dep).
- `tests/` — tests not already inside the patches (round-trip + NMS suite wiring).
- `release/` — `rollback.sh` (rungs A/B/FORWARD with backup gates),
  operator notes, config templates.
- `docs/` — per-loop engineering reports (research → validation).
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
