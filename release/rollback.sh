#!/usr/bin/env bash
#
# rollback.sh — Folia Linear rollforward/rollback.
#
#   Rung A (fast, proven live): flag flip back to ANVIL on the Linear jar.
#            Dual-read keeps existing .linear files readable; new writes go to .mca.
#   Rung B (full, 0-diffs proven): rung A + linear2mca convert-back + verify
#            + swap to the stock jar.
#   Rung FORWARD (rollforward): re-apply LINEAR opt-in to named worlds.
#
# Preflight gates (ALL rungs): jar sha match, free-space check, and a backup
# gate that ABORTS unless --backup-dir points at a VERIFIED snapshot
# (contains BACKUP_VERIFIED marker + at least one region/ tree).
#
# Read-only with respect to repos: touches only the live server dirs you name.
# Never reboots the server for you — you restart when ready.
#
set -euo pipefail

JAR_DEFAULT="/tmp/folia-linear/folia/folia-server/build/libs/folia-paperclip-26.1.2.local-SNAPSHOT.jar"
SHA_DEFAULT="3d4713a0c78a68d01f33cc9f44685cdfbbcd1b508cb1033cd4366f62b3cd618c"
CONVERTER_DEFAULT="/tmp/fork-study-adapt/convert.py"
STOCK_JAR_DEFAULT="/opt/folia-linear/stock/folia-paperclip-stock-26.1.2.jar"  # PLACEHOLDER: operator fills in

RUNG=""; WORLDS_DIR=""; BACKUP_DIR=""; JAR="$JAR_DEFAULT"; EXPECTED_SHA="$SHA_DEFAULT"
CONVERTER="$CONVERTER_DEFAULT"; STOCK_JAR="$STOCK_JAR_DEFAULT"
WORLDS=""; DRY_RUN=0; YES=0

usage() {
  cat <<'EOF'
usage: rollback.sh --rung A|B|FORWARD --worlds-dir DIR --backup-dir DIR [options]
  --rung A|B|FORWARD   A=flag flip to ANVIL, B=A+convert back+stock jar, FORWARD=re-apply LINEAR
  --worlds-dir DIR     live server worlds root (contains <world>/paper-world.yml or <world>/region/)
  --backup-dir DIR     verified snapshot root (must contain BACKUP_VERIFIED + a region/ tree)
  --worlds CSV         restrict to comma-separated world names (default: all with paper-world.yml)
  --jar PATH           Linear jar to verify (default: SHIP-CANDIDATE in place)
  --expected-sha HEX   (default: 3d4713a0...3cd618c)
  --converter PATH     L2-A8 convert.py (rung B only; default: /tmp/fork-study-adapt/convert.py)
  --stock-jar PATH     stock paperclip jar (rung B only; PLACEHOLDER default — set explicitly)
  --dry-run            print planned actions, change nothing
  --yes                required for rung B live convert/swap (else aborts after plan)
  --help               this text
EOF
}

log()  { printf '%s\n' "$*"; }
abort() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --rung) RUNG="${2:-}"; shift 2;;
    --worlds-dir) WORLDS_DIR="${2:-}"; shift 2;;
    --backup-dir) BACKUP_DIR="${2:-}"; shift 2;;
    --worlds) WORLDS="${2:-}"; shift 2;;
    --jar) JAR="${2:-}"; shift 2;;
    --expected-sha) EXPECTED_SHA="${2:-}"; shift 2;;
    --converter) CONVERTER="${2:-}"; shift 2;;
    --stock-jar) STOCK_JAR="${2:-}"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --yes) YES=1; shift;;
    --help|-h) usage; exit 0;;
    *) abort "unknown flag: $1 (see --help)";;
  esac
done

[ -n "$RUNG" ] || abort "missing --rung (see --help)"
[ -n "$WORLDS_DIR" ] || abort "missing --worlds-dir (see --help)"
[ -d "$WORLDS_DIR" ] || abort "worlds dir not found: $WORLDS_DIR"
case "$RUNG" in A|B|FORWARD) ;; *) abort "--rung must be A, B, or FORWARD";; esac

# ---- Gate 1: verified backup (ABORTS without one; no override flag) ----
[ -n "$BACKUP_DIR" ] || abort "no verified backup: pass --backup-dir pointing at a quiesced snapshot"
[ -d "$BACKUP_DIR" ] || abort "backup dir not found: $BACKUP_DIR"
[ -f "$BACKUP_DIR/BACKUP_VERIFIED" ] || abort "backup not verified: $BACKUP_DIR/BACKUP_VERIFIED missing (snapshot is not quiesced/recorded)"
if ! find "$BACKUP_DIR" -maxdepth 3 -type d -name region | grep -q .; then
  abort "backup looks empty: no region/ tree under $BACKUP_DIR"
fi
log "GATE backup: verified marker + region tree present under $BACKUP_DIR"

# ---- Gate 2: jar sha match ----
[ -f "$JAR" ] || abort "jar not found: $JAR"
ACTUAL_SHA="$(sha256sum "$JAR" | awk '{print $1}')"
[ "$ACTUAL_SHA" = "$EXPECTED_SHA" ] || abort "jar sha MISMATCH: got $ACTUAL_SHA want $EXPECTED_SHA"
log "GATE jar sha: MATCH ($JAR)"

# ---- Gate 3: free space (>= largest world size headroom; rung B needs ~2x) ----
WORLD_BYTES="$(du -sb "$WORLDS_DIR" | awk '{print $1}')"
FREE_BYTES="$(df --output=avail -B1 "$WORLDS_DIR" | tail -1 | tr -d ' ')"
NEED="$WORLD_BYTES"
[ "$RUNG" = "B" ] && NEED=$(( WORLD_BYTES * 2 ))
[ "$FREE_BYTES" -ge "$NEED" ] || abort "free space short: have ${FREE_BYTES}B need >= ${NEED}B on $(df --output=target "$WORLDS_DIR" | tail -1)"
log "GATE free space: have ${FREE_BYTES}B, need ${NEED}B — OK"

# ---- World list ----
list_worlds() {
  if [ -n "$WORLDS" ]; then
    echo "$WORLDS" | tr ',' ' '
  else
    for d in "$WORLDS_DIR"/*/; do
      [ -f "${d}paper-world.yml" ] && basename "$d"
    done
  fi
}

# Portable in-place format flip: replace an existing `format:` value under a
# `region-format:` block, else append a minimal block. Keeps a .pre-rollback copy.
flip_format() {
  local yml="$1" target="$2" changed=0
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY-RUN: would set region-format.format: $target in $yml"
    return 0
  fi
  cp -a "$yml" "$yml.pre-rollback"
  if grep -qE '^[[:space:]]*format:[[:space:]]' "$yml"; then
    # Only touch the first `format:` line that follows a `region-format:` line.
    perl -0pi -e "s/(region-format:\s*\n(?:.*\n)*?\s*)format:\s*\S+/\$1format: $target/" "$yml" && changed=1
  else
    printf '\nregion-format:\n  format: %s\n' "$target" >> "$yml" && changed=1
  fi
  [ "$changed" = "1" ] && log "FLIP $yml -> format: $target (backup: $yml.pre-rollback)"
}

case "$RUNG" in
  A)
    log "RUNG A: flag flip to ANVIL (Linear jar stays)."
    for w in $(list_worlds); do
      yml="$WORLDS_DIR/$w/paper-world.yml"
      [ -f "$yml" ] || { log "SKIP $w: no paper-world.yml"; continue; }
      flip_format "$yml" "ANVIL"
    done
    log "RUNG A DONE. Next: restart server, confirm no SEVERE [region-format] lines,"
    log "new chunks land as r.X.Z.mca; existing .linear files remain readable (dual-read)."
    ;;
  FORWARD)
    log "RUNG FORWARD: re-apply LINEAR opt-in (rollforward)."
    for w in $(list_worlds); do
      yml="$WORLDS_DIR/$w/paper-world.yml"
      [ -f "$yml" ] || { log "SKIP $w: no paper-world.yml"; continue; }
      flip_format "$yml" "LINEAR"
    done
    log "FORWARD DONE. Next: restart, verify .linear growth per OPERATOR-NOTES.md §3."
    ;;
  B)
    log "RUNG B: full rollback (flag flip + linear2mca + verify + stock jar)."
    [ -x "$CONVERTER" ] || [ -f "$CONVERTER" ] || abort "converter not found: $CONVERTER"
    [ "$DRY_RUN" = "1" ] || [ "$YES" = "1" ] || abort "rung B changes data: re-run with --dry-run or --yes"
    # B1: flag flip first so any restart mid-procedure writes ANVIL.
    for w in $(list_worlds); do
      yml="$WORLDS_DIR/$w/paper-world.yml"
      [ -f "$yml" ] || { log "SKIP $w: no paper-world.yml"; continue; }
      flip_format "$yml" "ANVIL"
    done
    # B2: convert each world tree back and verify 0 diffs.
    for w in $(list_worlds); do
      src="$WORLDS_DIR/$w"
      [ -d "$src/region" ] || { log "SKIP $w: no region/ tree"; continue; }
      tmp="$(mktemp -d "${TMPDIR:-/tmp}/linear-rollback-${w}.XXXXXX")"
      log "CONVERT $w: linear2mca $src -> $tmp/mca"
      if [ "$DRY_RUN" = "1" ]; then
        log "DRY-RUN: would run: python3 $CONVERTER linear2mca $src $tmp/mca"
        log "DRY-RUN: would run: python3 $CONVERTER verify $src $tmp/mca (expect total diffs=0)"
        log "DRY-RUN: would swap converted .mca trees into $src after verify passes"
        rm -rf "$tmp"
        continue
      fi
      python3 "$CONVERTER" linear2mca "$src" "$tmp/mca" || abort "linear2mca failed for $w"
      python3 "$CONVERTER" verify "$src" "$tmp/mca" 2>&1 | tail -5 || true
      # NOTE: verify compares .mca-vs-.mca chunk payloads; require explicit 0-diff
      # line before touching the live tree.
      if python3 "$CONVERTER" verify "$src" "$tmp/mca" 2>&1 | grep -q "total diffs=0"; then
        log "VERIFY $w: 0 diffs — syncing .mca trees into $src"
        (cd "$tmp/mca" && find region poi entities -name '*.mca' 2>/dev/null | while read -r f; do
          mkdir -p "$src/$(dirname "$f")"; cp -a "$tmp/mca/$f" "$src/$f"
        done)
        log "SYNC $w done. Remove stale .linear files ONLY after a clean boot (see OPERATOR-NOTES.md)."
      else
        abort "verify for $w shows diffs — live tree untouched, converted output kept at $tmp/mca"
      fi
      rm -rf "$tmp"
    done
    # B3: stock jar swap (placeholder path — operator must provide the real one).
    # In dry-run the missing placeholder is a WARNING (plan still completes);
    # live, it is a hard abort with instructions.
    if [ ! -f "$STOCK_JAR" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        log "DRY-RUN: stock jar not yet provided (placeholder missing: $STOCK_JAR) — live rung B would abort here until --stock-jar points at the real stock jar"
      else
        abort "stock jar not found at $STOCK_JAR — set --stock-jar to the real stock paperclip jar; live tree already flipped to ANVIL (safe to stop here)"
      fi
    elif [ "$DRY_RUN" = "1" ]; then
      log "DRY-RUN: would swap server jar to stock: $STOCK_JAR"
    else
      log "STOCK JAR ready: $STOCK_JAR"
      log "Swap it into your start script / server dir, restart, and confirm boot with no [region-format] lines."
    fi
    log "RUNG B DONE."
    ;;
esac
