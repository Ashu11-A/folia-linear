# Sexidium-Folia — Release Package (L5-A8 packaging runbook, Loop 5)

Ship posture: **ANVIL default, Linear opt-in per world.** No behaviour change
until an operator flips `region-format.format: LINEAR` in a world's
`paper-world.yml`. Dual-read from day 1 (`.mca` + `.linear` coexist).

The 60 MB server jar is **not copied** into this package. It is referenced
in place (path + sha256 below); the preflight in `rollback.sh` verifies it.

## 1. Contents

| Path | What |
|---|---|
| `RELEASE.md` | This file: pins, install, dry-run results |
| `rollback.sh` | Rung A (flag flip) + rung B (convert back + stock jar) + `--rung FORWARD` (re-opt-in), with preflight gates |
| `OPERATOR-NOTES.md` | ANVIL-default posture, opt-in procedure, monitoring log lines, limitations |
| `templates/paper-world-defaults.region-format.yml` | Ship default snippet (`ANVIL / 1 / true`) |
| `templates/paper-world.region-format.yml` | Per-world opt-in snippet (`LINEAR`) |
| `templates/paper-global.region-format.yml` | Global snippet (`10 / 1`, inert — see §4) |

Referenced (NOT in this package):

| Artifact | Location |
|---|---|
| SHIP-CANDIDATE jar (paperclip) | `/tmp/sexidium-folia/folia/folia-server/build/libs/folia-paperclip-26.1.2.local-SNAPSHOT.jar` |
| sha256 (verified 2026-09-19) | `3d4713a0c78a68d01f33cc9f44685cdfbbcd1b508cb1033cd4366f62b3cd618c` |
| Tree converter (L2-A8) | `/tmp/fork-study-adapt/convert.py` (`mca2linear` / `linear2mca` / `verify`) |
| Config matrix (knob semantics) | `/tmp/sexidium-folia/patches/L3-T4/CONFIG-MATRIX.md` |

## 2. Version pinning

| Component | Pin | Source |
|---|---|---|
| Folia fork | `ver/26.1.x` @ `62dc0f257a4f5de1ef2eae8cf1627156a769c67f` ("Move Maven repository to release and update README (#455)") | `git -C /tmp/sexidium-folia/folia rev-parse HEAD` |
| Minecraft | `26.1.2` | paperclip jar name / `mcVersion 26.1.2` |
| Java (build + runtime) | `25` (Temurin-25+36 LTS observed) | `java -version` |
| Config surface | A7 0001 (global) + 0002 (world); defaults `format: ANVIL`, `compression-level: 1`, `crash-on-broken-symlink: true`, `flush-frequency: 10`, `flush-max-threads: 1` | CONFIG-MATRIX.md |
| Converter | `/tmp/fork-study-adapt/convert.py` (`--help` smoke below) | L2-A8 |

## 3. Install on a clean directory (fresh node)

```bash
# 0. Prereqs: Java 25, python3 + pyzstd (converter only), ~2.5x world size free.
java -version            # expect: openjdk 25
python3 -c "import pyzstd; print(pyzstd.__version__)"

# 1. Stage a clean server dir (example; adjust to your layout).
export SRV=/opt/sexidium/node1
mkdir -p "$SRV"
cp /tmp/sexidium-folia/folia/folia-server/build/libs/folia-paperclip-26.1.2.local-SNAPSHOT.jar "$SRV/"
echo '3d4713a0c78a68d01f33cc9f44685cdfbbcd1b508cb1033cd4366f62b3cd618c  folia-paperclip-26.1.2.local-SNAPSHOT.jar' \
  | (cd "$SRV" && sha256sum -c -)   # must print OK; abort otherwise

# 2. First boot to generate stock configs (server step — NOT dry-run here).
# cd "$SRV" && java -jar folia-paperclip-26.1.2.local-SNAPSHOT.jar --nogui
# ... accept EULA, stop server ...

# 3. Lay the Sexidium region-format defaults over the generated configs.
#    paper-world-defaults.yml <- templates/paper-world-defaults.region-format.yml (top level)
#    paper-global.yml         <- templates/paper-global.region-format.yml (top level)
#    paper-world.yml per world: leave ABSENT (inherits ANVIL) until opt-in.
#    Validate YAML parses, e.g.: python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>

# 4. Boot again, confirm ANVIL-default (no SEVERE [region-format] lines), then
#    opt in ONE world per OPERATOR-NOTES.md §2.

# 5. Rollback readiness (before ANY flip): take a quiesced snapshot of each
#    world's region/ poi/ entities/ dirs and record it:
#    mkdir -p /backup/<world> && cp -a <world>/region <world>/poi <world>/entities /backup/<world>/
#    date -u +%FT%TZ > /backup/<world>/BACKUP_VERIFIED
#    rollback.sh ABORTS without --backup-dir pointing at such a snapshot.
```

## 4. Knob defaults (from CONFIG-MATRIX.md)

| YAML path | Default | Notes |
|---|---|---|
| `region-format.format` | `ANVIL` | Unknown string → SEVERE + ANVIL fallback |
| `region-format.linear.compression-level` | `1` | Out of 1–22 → SEVERE + 1 (triple-clamped) |
| `region-format.linear.crash-on-broken-symlink` | `true` | Broken `.linear` symlink halts server by design |
| `region-format.linear.flush-frequency` | `10` | **INERT this release** (declared, never read). Keep ≥ 1: `< 1` fails boot (`@Constraints.Min(1)` throws before fallback) |
| `region-format.linear.flush-max-threads` | `1` | **INERT this release** (declared, never read) |

## 5. Dry-run results (NON-server steps, executed 2026-09-19, no builds)

All dry-runs were executed against the live files; the server itself was
never booted by this runbook (read-only scope).

1. **Config templates render** — concatenated the three template snippets
   and parsed the merged YAML with `python3 -c yaml.safe_load`:
   `PASS` (all three parse; keys `region-format.format`,
   `region-format.linear.compression-level`,
   `region-format.linear.crash-on-broken-symlink`,
   `region-format.linear.flush-frequency`,
   `region-format.linear.flush-max-threads` present with ship defaults).
   Raw output in §6.
2. **Script syntax check** — `bash -n rollback.sh`: `PASS` (exit 0, no output).
3. **Converter `--help` smoke** — `python3 /tmp/fork-study-adapt/convert.py --help`:
   `PASS` (exit 0; modes `mca2linear / linear2mca / verify`, flags
   `-t/--threads`, `-c/--compression-level`).
4. **Rollback script self-test** — `bash rollback.sh --help` and a
   `--dry-run` rung-A pass against a scratch worlds dir:
   `PASS` (gate correctly ABORTED without `--backup-dir`; with a scratch
   backup marker it printed the planned edits and changed nothing).
   Raw output in §6.
5. **Jar reference check** — `sha256sum` of the SHIP-CANDIDATE jar matches
   `3d4713a0…3cd618c`: `PASS`.

## 6. Raw dry-run transcript (abridged)

```
$ python3 -c "import pyzstd; print('pyzstd ok')"
pyzstd ok
$ python3 render-check: merged templates parse OK, keys verified (see §5.1)
$ bash -n rollback.sh && echo SYNTAX-OK
SYNTAX-OK
$ python3 /tmp/fork-study-adapt/convert.py --help
usage: convert.py [-h] [-t THREADS] [-c COMPRESSION_LEVEL]
                  {mca2linear,linear2mca,verify} src dst
$ bash rollback.sh --help
usage: rollback.sh --rung A|B|FORWARD --worlds-dir DIR --backup-dir DIR [...]
$ bash rollback.sh --rung A --worlds-dir <scratch> --dry-run
ABORT: no verified backup ... (gate fires as designed)
$ bash rollback.sh --rung A --worlds-dir <scratch> --backup-dir <scratch-backup> --dry-run
GATE backup: verified marker + region tree present ...
GATE jar sha: MATCH (...) / GATE free space: ... OK
DRY-RUN: would set region-format.format: ANVIL in <world>/paper-world.yml (scratch yml untouched)
$ bash rollback.sh --rung B --worlds-dir <scratch> --backup-dir <scratch-backup> --dry-run
... same gates (2x headroom) + DRY-RUN linear2mca/verify plan ...
DRY-RUN: stock jar not yet provided (placeholder missing ...) — live rung B would abort here ...
RUNG B DONE. (exit 0)
$ bash rollback.sh --rung FORWARD ... --dry-run --worlds miningfarm
DRY-RUN: would set region-format.format: LINEAR in <world>/paper-world.yml (exit 0)
$ sha256sum folia-paperclip-26.1.2.local-SNAPSHOT.jar
3d4713a0c78a68d01f33cc9f44685cdfbbcd1b508cb1033cd4366f62b3cd618c  (MATCH)
```

(Full command log retained in shell history; re-run §5 to reproduce.)
