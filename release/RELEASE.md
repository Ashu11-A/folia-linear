# Release package

Ship posture: Anvil default, Linear opt-in per world. Nothing changes until an
operator sets `region-format.format: LINEAR` in a world's `paper-world.yml`.
Dual-read is active from the first boot, so `.mca` and `.linear` coexist.

The server jar is not copied into this directory. It is referenced by path and
sha256 below, and `rollback.sh` verifies it before acting.

## 1. Contents

| Path | What |
|---|---|
| `RELEASE.md` | This file: pins, install, dry-run results |
| `rollback.sh` | Rung A (flag flip), rung B (convert back plus stock jar), rung FORWARD (re-opt-in), all behind preflight gates |
| `OPERATOR-NOTES.md` | Posture, opt-in procedure, monitoring, limitations |
| `paper-world-defaults.region-format.yml` | Ship default snippet: `ANVIL`, level `1`, symlink guard on |
| `paper-world.region-format.yml` | Per-world opt-in snippet: `LINEAR` |
| `paper-global.region-format.yml` | Global snippet: the two inert flush keys |

Referenced but not included:

| Artifact | Where |
|---|---|
| Paperclip jar | Built locally, or `folia-linear-<mcversion>-<project>.jar` from the GitHub release for a project `v*` tag (legacy `v<mc>-linear.N` tags carry `folia-<mcversion>-<build>.jar`) |
| Tree converter | `convert.py`, modes `mca2linear`, `linear2mca`, `verify`. Not part of this repository |

## 2. Version pins

Single source of truth: `versions/<line>/upstream.properties` (keys
`FOLIA_REPO`, `FOLIA_BRANCH`, `FOLIA_REF`, `MC_VERSION`). The table below is
the 26.1.x instantiation of that file; the workflow pins mirror it.

| Component | Pin |
|---|---|
| Folia base | `ver/26.1.x` at `62dc0f257a4f5de1ef2eae8cf1627156a769c67f` |
| Minecraft | `26.1.2` |
| Java, build and runtime | `25` (verified on Temurin 25+36 LTS) |
| zstd-jni | `1.5.6-8` |
| Config defaults | `format: ANVIL`, `compression-level: 1`, `crash-on-broken-symlink: true`, `flush-frequency: 10`, `flush-max-threads: 1` |

The reference build produced a 60,509,601 B paperclip jar with sha256
`3d4713a0c78a68d01f33cc9f44685cdfbbcd1b508cb1033cd4366f62b3cd618c`, reproducible
byte for byte across rebuilds. A CI release asset is a different artifact and
therefore has a different sha: `folia-26.1.2-1.jar` is 60,511,732 B,
`folia-26.1.2-3.jar` is 60,530,852 B. `rollback.sh --expected-sha` defaults to
the local reference build, so pass the sha of whichever jar you actually
deployed.

## 3. Install on a clean node

```bash
# 0. Prereqs: Java 25, python3 with pyzstd if you will use the converter,
#    and roughly 2.5x the world size free.
java -version

# 1. Stage the server directory.
export SRV=/opt/folia-linear/node1
mkdir -p "$SRV"
cp <paperclip jar> "$SRV/"
(cd "$SRV" && sha256sum -c - <<<"<expected sha>  <jar name>")   # must print OK

# 2. First boot to generate stock configs, then stop.
#    cd "$SRV" && java -jar <jar> --nogui
#    Accept the EULA, stop the server.

# 3. Lay the region-format defaults over the generated configs.
#    paper-world-defaults.yml  <- paper-world-defaults.region-format.yml (top level)
#    paper-global.yml          <- paper-global.region-format.yml (top level)
#    Per-world paper-world.yml: leave the block out until opt-in; the world
#    inherits ANVIL.
#    Validate: python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>

# 4. Boot again and confirm no [region-format] lines appear, then opt one world
#    in per OPERATOR-NOTES.md section 2.

# 5. Rollback readiness, before any flip:
mkdir -p /backup/<world>
cp -a <world>/region <world>/poi <world>/entities /backup/<world>/
date -u +%FT%TZ > /backup/<world>/BACKUP_VERIFIED
#    rollback.sh aborts unless --backup-dir points at a snapshot like this.
```

## 4. Knob defaults

| Key | Default | Notes |
|---|---|---|
| `region-format.format` | `ANVIL` | Unknown string logs an error and falls back to `ANVIL` |
| `region-format.linear.compression-level` | `1` | Outside 1-22 logs an error and falls back to `1`, clamped in three places |
| `region-format.linear.crash-on-broken-symlink` | `true` | A broken `.linear` symlink halts the server by design |
| `region-format.linear.flush-frequency` | `10` | Inert in this release. Below 1 logs an error and falls back to `10` |
| `region-format.linear.flush-max-threads` | `1` | Inert in this release |

The timing counters and `/linearstats` add no config keys.

Full reference: [../docs/configuration.md](../docs/configuration.md).

## 5. Dry-run results

Executed 2026-09-19 against the live files. The server itself was not booted by
this runbook.

1. **Config templates render.** The three snippets concatenated and parsed with
   `yaml.safe_load`: pass. All five keys present with ship defaults.
2. **Script syntax.** `bash -n rollback.sh`: pass, exit 0, no output.
3. **Converter smoke.** `convert.py --help`: pass. Modes `mca2linear`,
   `linear2mca`, `verify`; flags `-t/--threads`, `-c/--compression-level`.
4. **Rollback self-test.** `rollback.sh --help`, plus a rung A `--dry-run`
   against a scratch worlds directory: pass. The gate correctly aborted without
   `--backup-dir`; with a scratch backup marker it printed the planned edits and
   changed nothing.
5. **Jar reference check.** sha256 matched the expected value: pass.

Abridged transcript:

```
$ bash -n rollback.sh && echo SYNTAX-OK
SYNTAX-OK
$ python3 convert.py --help
usage: convert.py [-h] [-t THREADS] [-c COMPRESSION_LEVEL]
                  {mca2linear,linear2mca,verify} src dst
$ bash rollback.sh --rung A --worlds-dir <scratch> --dry-run
ABORT: no verified backup ... (gate fires as designed)
$ bash rollback.sh --rung A --worlds-dir <scratch> --backup-dir <scratch-backup> --dry-run
GATE backup: verified marker + region tree present ...
GATE jar sha: MATCH (...) / GATE free space: ... OK
DRY-RUN: would set region-format.format: ANVIL in <world>/paper-world.yml
$ bash rollback.sh --rung B --worlds-dir <scratch> --backup-dir <scratch-backup> --dry-run
... same gates at 2x headroom, plus the linear2mca and verify plan ...
DRY-RUN: stock jar not yet provided (placeholder missing) - live rung B would abort here
RUNG B DONE. (exit 0)
$ bash rollback.sh --rung FORWARD ... --dry-run --worlds miningfarm
DRY-RUN: would set region-format.format: LINEAR in <world>/paper-world.yml (exit 0)
```

## 6. Per-version builds

The supplement is version-scoped: each supported line lives in
`versions/<branch>/` with its own pin (`upstream.properties`), `patches/`,
`tests/` and `build-hunk.py`.

```bash
scripts/build.sh --mc 26.1.x   # this release line
scripts/build.sh               # every folder in versions/
```

Each line produces its own paperclip jar. Release tags carry the **project
version only** (`v1.4.0`); one release attaches one jar + `.sha256` per
supported version, named `folia-linear-<mcversion>-<project>.jar` (so a
`v1.4.0` release containing `26.1.x` at MC `26.1.2` ships
`folia-linear-26.1.2-1.4.0.jar` + `.sha256`; a future `26.2.x` line at MC
`26.2.1` would add `folia-linear-26.2.1-1.4.0.jar` + `.sha256` to the same
release). Verify the sha256 shipped alongside the jar before
`rollback.sh --expected-sha` will accept it.

To release only some folders (a fix that applies to one line), dispatch the
workflow manually on the tag with the `versions` input:

```bash
gh workflow run build.yml --ref v1.4.0 -f versions=26.1.x
```

Pushed tags always release every version. The `v26.1.2-linear.1..3` tags and
their `folia-<mcversion>-<build>.jar` assets stay as history; the workflow
still understands that legacy tag shape, but new releases use the project
scheme.
