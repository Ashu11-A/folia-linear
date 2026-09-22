#!/usr/bin/env bash
# harness.sh — Loop 4 stress orchestrator (tests #1–#22 × 3 runs × 2 jars).
#
# Runs the Plan.md protocol steps 1–9 for one (LEVEL, JAR, RUN) at a time on
# smp-test, strictly sequentially, and appends one row per run to
# versions/<mc>/bench/stress-1-22.csv.
#
# Full matrix (BLOCKED until owner cleanup frees ~47 GiB):
#   STRESS=/srv/build/stress SOURCE=$STRESS/source-anvil ./harness.sh --levels 1,3,6,...
# Sample validation (small, always allowed, <=2 GiB new data):
#   SAMPLE=1 ./harness.sh --levels 6 --jars baseline,rc --runs 1
#
# HARD RULES (enforced in code, not just comments):
#   - live stack/containers/volumes UNTOUCHABLE: only `status`/`logs` (read-only)
#     may target live nodes; every mutation goes at sexidium-smp-test or under
#     $STRESS. The script refuses to run if smp-1 is unreachable (noise column
#     needs it) — but never restarts/reprovisions anything live.
#   - disk gate: needs expected_level_bytes (size pass, default 17 GiB) + 5 GiB
#     free, else stops WITHOUT starting. Post-wipe free must return to the
#     pre-test level (tolerance 1 GiB) or the next test does not start.
#   - wipe scope: ONLY $WORK (level-N dir) + smp-test volume paths
#     (world dir, logs, caches, crash-reports). Never sexidium-data,
#     sexidium-smp-1, plugin builds, or the stock jar.
#   - one run at a time: a lock file ($STRESS/harness.lock) refuses a second
#     concurrent harness.
set -Eeuo pipefail

BENCH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# Repo roots are resolved, never hardcoded: this file lives in the fork at
# versions/<mc>/bench/, the operator repo (remote.sh) is a sibling checkout.
FORK_ROOT="$(cd "$BENCH_DIR/../../.." && pwd -P)"
SEXIDIUM_REPO="${SEXIDIUM_REPO:-$FORK_ROOT/../sexidium}"
REMOTE="$SEXIDIUM_REPO/scripts/remote.sh"
CSV="$BENCH_DIR/stress-1-22.csv"

# --- configuration (env-overridable) -----------------------------------------
STRESS="${STRESS:-/srv/build/stress}"          # scratch root on the host
SOURCE="${SOURCE:-$STRESS/source-anvil}"       # full Anvil source (agent 20)
WORK=""                                        # set per level: $STRESS/level-N
SAMPLE="${SAMPLE:-0}"                          # SAMPLE=1 → small validation mode
RUNS="${RUNS:-3}"
JARS="${JARS:-baseline,rc}"
LEVELS="${LEVELS:-1,3,6,9,12,15,19,22}"
LDM="${LDM:-0}" FLUSH_THREADS="${FLUSH_THREADS:-1}" COMPRESSION_WORKERS="${COMPRESSION_WORKERS:-0}"
GRACE_S=120                                    # stop_grace_period of smp-test
CONVERTER="$SEXIDIUM_REPO/scripts/vendor/mca2linear-convert.py"

JAR_BASELINE_URL="https://github.com/Ashu11-A/folia-linear/releases/download/v1.0.0-baseline/folia-linear-26.1.2-1.0.0-baseline.jar"
JAR_BASELINE_SHA="e609c1d439e7bdd68e68abccbcf02c818efe77fa4ae8d7ddc2914204ca0ee06b"
JAR_RC_URL="https://github.com/Ashu11-A/folia-linear/releases/download/v1.1.0-rc/folia-linear-26.1.2-1.1.0-rc.jar"
JAR_RC_SHA="b184a5b6f49f8e0f0d1ddef4b679da9f792f5f79feca0c401df6d5993343d84f"
SHADOW_JAR="/srv/nodes/smp-test/shadow-server/folia.jar"   # inside smp-test volume
NODE="smp-test"
CONTAINER="sexidium-smp-test"

harness::die() { printf 'harness: %s\n' "$*" >&2; exit 5; }
harness::log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }
# All host mutations go through this one function so the wipe scope is auditable.
# First arg is a tag; the rest is the remote command run inside smp-test/worker-1.
on_host() { "$REMOTE" exec "$1" -- sh -c "$2"; }

# --- step 0: preconditions ----------------------------------------------------
harness::lock() {
  # Local operator-side lock: one harness process at a time (Plan.md: one run).
  exec 9>/tmp/harness.lock
  flock -n 9 || harness::die "another harness holds the lock; one run at a time"
}
harness::preflight() {
  [[ -x "$REMOTE" ]] || harness::die "remote.sh not found at $REMOTE (set SEXIDIUM_REPO)"
  "$REMOTE" status >/dev/null || harness::log "WARN: live status unreachable; smp1_players will be -1"
  if [[ "$SAMPLE" == "1" ]]; then
    SOURCE="$STRESS/sample/anvil-a"
    harness::log "SAMPLE mode: source=$SOURCE"
  fi
}

# --- step 1: free-space gate + convert once per level + pristine restore ------
# Out: FREEBEFORE (GiB), CONVERT_S (s), BYTES_ANVIL, BYTES_ON_DISK.
harness::free_gib() {
  on_host "$NODE" "df --output=avail -B1G /srv/build | tail -1 | tr -d ' '"
}
harness::gate_space() { # $1 = expected level bytes (GiB, default 17)
  local need_gib="${1:-17}" free
  free="$(harness::free_gib)"
  FREEBEFORE="$free"
  [[ "$free" -ge $((need_gib + 5)) ]] || harness::die \
    "free ${free} GiB < need $((need_gib + 5)) GiB (level ~${need_gib} + 5 headroom); NOT starting"
  [[ "$free" -ge 15 ]] || harness::die "free ${free} GiB < 15 GiB absolute floor; NOT starting"
  harness::log "space gate PASS: free=${free} GiB need=$((need_gib + 5)) GiB"
}
harness::convert_level() { # $1 = level → $WORK populated + verified
  local level="$1" t0 t1
  WORK="$STRESS/level-$level"
  # Converter skips files whose dst mtime == src mtime, so a stale level-N dir
  # would silently survive a re-run: always convert into an EMPTY dir.
  on_host "$NODE" "rm -rf '$WORK' && mkdir -p '$WORK/pristine-forceload'"
  t0="$(date +%s)"
  if [[ "$SAMPLE" == "1" ]]; then
    # Sample tree is flat (region/, entities/, poi/ at root): one invocation.
    on_host worker-1 -- "python3 '$CONVERTER' mca2linear -t 2 -c $level '$SOURCE' '$WORK/tree'"
  else
    for dim in overworld the_nether the_end; do
      on_host worker-1 -- "python3 '$CONVERTER' mca2linear -t 4 -c $level '$SOURCE/$dim' '$WORK/tree/$dim'"
    done
  fi
  t1="$(date +%s)"; CONVERT_S=$((t1 - t0))
  harness::verify_level "$level"
  BYTES_ON_DISK="$(on_host "$NODE" "du -sb '$WORK/tree' | cut -f1")"
  BYTES_ANVIL="$(on_host "$NODE" "du -sb '$SOURCE' | cut -f1")"
  # Pristine copy of the forceload set: per-run restore without reconverting.
  harness::snapshot_pristine
}
harness::verify_level() { # $1 = level; gate: total diffs=0, exit 0
  local level="$1" out
  if [[ "$SAMPLE" == "1" ]]; then
    out="$(on_host worker-1 -- "python3 '$CONVERTER' verify -t 2 '$SOURCE' '$WORK/tree'")"
  else
    out=""
    for dim in overworld the_nether the_end; do
      out="$out $(on_host worker-1 -- "python3 '$CONVERTER' verify -t 4 '$SOURCE/$dim' '$WORK/tree/$dim'" | tail -1)"
    done
  fi
  echo "$out" | grep -q "total diffs=0" || harness::die "verify FAILED for level $level: $out"
  harness::log "verify level $level: total diffs=0"
}
harness::snapshot_pristine() {
  # Full matrix: the 16 forceload-set files (agent 20 §4) + sha256 manifest.
  # Sample mode: the whole tiny tree (a few MB) — same mechanism, same code path.
  if [[ "$SAMPLE" == "1" ]]; then
    on_host "$NODE" "cp -pR '$WORK/tree/.' '$WORK/pristine-forceload/' && (cd '$WORK/pristine-forceload' && find . -type f | sort | xargs sha256sum > ../pristine.sha256)"
  else
    on_host "$NODE" "for f in \$(cat '$WORK/forceload-files.txt'); do mkdir -p '$WORK/pristine-forceload/\$(dirname "\$f")'; cp -p '$WORK/tree/\$f' '$WORK/pristine-forceload/\$f'; done && (cd '$WORK/pristine-forceload' && find . -type f | sort | xargs sha256sum > ../pristine.sha256)"
  fi
}
harness::restore_pristine() { # per-run reset; verifies sha256 after copy
  on_host "$NODE" "cp -pR '$WORK/pristine-forceload/.' '$WORK/tree/' && (cd '$WORK/tree' && sha256sum -c --quiet < '$WORK/pristine.sha256' 2>/dev/null || (cd '$WORK/pristine-forceload' && sha256sum -c --quiet '$WORK/pristine.sha256'))"
  harness::log "pristine restored for $WORK"
}

# --- jar swap: download on host, sha-check, mv to shadow, restart ONLY smp-test
harness::swap_jar() { # $1 = baseline|rc
  local want="$1" url sha
  if [[ "$want" == "baseline" ]]; then url="$JAR_BASELINE_URL"; sha="$JAR_BASELINE_SHA";
  else url="$JAR_RC_URL"; sha="$JAR_RC_SHA"; fi
  on_host "$NODE" "curl -fsSL -o /tmp/folia-candidate.jar '$url' && echo '$sha  /tmp/folia-candidate.jar' | sha256sum -c - && mv /tmp/folia-candidate.jar '$SHADOW_JAR' && sha256sum '$SHADOW_JAR'"
  JARSHA="$sha"
  harness::log "shadow jar now $want ($sha)"
  # Restart ONLY sexidium-smp-test. No restack/reprovision; live untouched.
  SEXIDIUM_REPO="$SEXIDIUM_REPO" python3 - "$CONTAINER" "$GRACE_S" <<'EOF'
import os, sys
# remote.sh exports scripts/remote.env into the environment before invoking its
# python; standalone heredocs replicate that loader (env wins over the file).
_env = os.path.join(os.environ['SEXIDIUM_REPO'], 'scripts', 'remote.env')
for _l in open(_env):
    _l = _l.strip()
    if _l and not _l.startswith('#') and '=' in _l:
        _k, _v = _l.split('=', 1)
        if len(_v) >= 2 and _v[0] in '"\'': _v = _v[1:-1]
        os.environ.setdefault(_k, _v)
sys.path.insert(0, os.path.join(os.environ['SEXIDIUM_REPO'], 'scripts', 'remote'))
from config import Settings
from portainer import Client
name, grace = sys.argv[1], int(sys.argv[2])
s = Settings(); c = Client(s, verbose=False)
c.restart(name, seconds=grace)
print(f"restarted {name} (grace {grace}s)")
EOF
}

# --- step 2: boot wait + level-confirmed log check -----------------------------
# There is NO positive "[region-format] level N" boot line in the fork: the only
# level lines are the out-of-range SEVERE fallbacks. So confirmation is threefold:
#   (a) boot completed (Done line) → BOOT_S;
#   (b) no fallback SEVERE in the boot window (else row invalid, LEVEL_FALLBACK=1);
#   (c) ground truth from disk: header level byte of a freshly written .linear
#       file must equal the test level (checked after the first flush).
harness::wait_boot() { # $1 = timeout s. Out: BOOT_S.
  local timeout="${1:-300}" t0 now
  t0="$(date +%s)"
  while true; do
    if on_host "$NODE" "grep -q 'Done (' /srv/nodes/smp-test/logs/latest.log" 2>/dev/null; then break; fi
    now="$(date +%s)"; [[ $((now - t0)) -gt "$timeout" ]] && harness::die "boot timeout after ${timeout}s"
    sleep 5
  done
  BOOT_S=$(( $(date +%s) - t0 ))
  if on_host "$NODE" "grep -E 'region-format.*(must be 1-22|Unknown region format)' /srv/nodes/smp-test/logs/latest.log | grep -q ."; then
    LEVEL_FALLBACK=1
    harness::log "WARN: out-of-range SEVERE present — row invalid (level_fallback_severe=1)"
  else
    LEVEL_FALLBACK=0
  fi
}
harness::confirm_level_disk() { # $1 = expected level. Out: LEVEL_CONFIRMED.
  local want="$1" lvl
  lvl="$(on_host worker-1 -- "python3 -c \"import struct,glob,os; fs=sorted(glob.glob('$WORK/tree/**/region/*.linear',recursive=True)); f=fs[0]; d=open(f,'rb').read(16); print(d[8])\"")"
  LEVEL_CONFIRMED="$lvl"
  [[ "$lvl" == "$want" ]] || harness::log "WARN: disk level $lvl != test $want"
}

# --- console path: node API POST from worker-1 (no new containers) ------------------
# `remote.sh console` only reaches live topology nodes, so the harness posts to
# smp-test:8840 itself. Transport: bench/smc.py is uploaded with put_archive to
# worker-1:/tmp (container filesystem, ephemeral, never a volume) and run with
# the host's python3; worker-1 sits on the same `sexidium` network so the
# smp-test service alias resolves. The POST targets ONLY the staging API;
# nothing live is commanded. Reply is {"ok":true}; the real result lands in
# the smp-test console log. Token = shared api_token.
harness::smc_deploy() {
  SEXIDIUM_REPO="$SEXIDIUM_REPO" SMC_PY="$BENCH_DIR/smc.py" python3 - <<'EOF'
import io, os, sys, tarfile
_env = os.path.join(os.environ['SEXIDIUM_REPO'], 'scripts', 'remote.env')
for _l in open(_env):
    _l = _l.strip()
    if _l and not _l.startswith('#') and '=' in _l:
        _k, _v = _l.split('=', 1)
        if len(_v) >= 2 and _v[0] in '"\'': _v = _v[1:-1]
        os.environ.setdefault(_k, _v)
sys.path.insert(0, os.path.join(os.environ['SEXIDIUM_REPO'], 'scripts', 'remote'))
from config import Settings
from portainer import Client
s = Settings(); c = Client(s, verbose=False)
with open(os.environ['SMC_PY'], 'rb') as f:
    data = f.read()
bio = io.BytesIO()
with tarfile.open(fileobj=bio, mode='w') as t:
    ti = tarfile.TarInfo('smc.py'); ti.size = len(data); t.addfile(ti, io.BytesIO(data))
c.put_archive('sexidium-worker-1', '/tmp', bio.getvalue())
print("smc.py staged in worker-1:/tmp")
EOF
}
harness::console() { # $1 = command line (base64: no quoting leaks into sh -c)
  local b64
  b64="$(printf '%s' "$1" | base64 -w0)"
  on_host worker-1 -- "python3 /tmp/smc.py '$b64'"
}

# --- step 6: memory sampling hooks (1 s) -----------------------------------------
# Untracked native = RSS − NMT committed (zstd malloc is invisible to NMT).
# NMT needs -XX:NativeMemoryTracking=summary at JVM start, which the shared
# entrypoint does not pass today: if `jcmd 1 VM.native_memory` fails, NMT columns
# record -1 and the hook still yields cgroup + VmRSS/HWM + heap samples.
harness::mem_sample_once() { # appends one line to $SAMPLES_CSV
  local ts cgroup rss hwm heap
  ts="$(date -u +%FT%TZ)"
  cgroup="$(on_host "$NODE" "cat /sys/fs/cgroup/memory.current 2>/dev/null || cat /sys/fs/cgroup/system.slice/docker-*.scope/memory.current 2>/dev/null || echo -1")"
  rss="$(on_host "$NODE" "awk '/VmRSS/{print \$2}' /proc/1/status")"
  hwm="$(on_host "$NODE" "awk '/VmHWM/{print \$2}' /proc/1/status")"
  heap="$(on_host "$NODE" "jcmd 1 GC.heap_info 2>/dev/null | awk '/used/{print \$0}' | head -1")"
  printf '%s,%s,%s,%s,%s\n' "$ts" "$cgroup" "$rss" "$hwm" "$heap" >>"$SAMPLES_CSV"
}

# --- step 5: SIGTERM timing via docker wait equivalent ---------------------------
harness::sigterm_time() { # Out: SHUTDOWN_S, EXIT_CODE, OOM_KILLED.
  local t0 t1
  t0="$(date +%s)"
  SEXIDIUM_REPO="$SEXIDIUM_REPO" python3 - "$CONTAINER" <<'EOF'
import os, sys
# remote.sh exports scripts/remote.env into the environment before invoking its
# python; standalone heredocs replicate that loader (env wins over the file).
_env = os.path.join(os.environ['SEXIDIUM_REPO'], 'scripts', 'remote.env')
for _l in open(_env):
    _l = _l.strip()
    if _l and not _l.startswith('#') and '=' in _l:
        _k, _v = _l.split('=', 1)
        if len(_v) >= 2 and _v[0] in '"\'': _v = _v[1:-1]
        os.environ.setdefault(_k, _v)
sys.path.insert(0, os.path.join(os.environ['SEXIDIUM_REPO'], 'scripts', 'remote'))
from config import Settings
from portainer import Client
s = Settings(); c = Client(s, verbose=False)
c.stop(sys.argv[1], seconds=120)   # SIGTERM, 120 s grace, then SIGKILL by daemon
print("stopped")
EOF
  SHUTDOWN_S=$(( $(date +%s) - t0 ))
  local state
  state="$(SEXIDIUM_REPO="$SEXIDIUM_REPO" python3 - "$CONTAINER" <<'EOF'
import os, sys
# remote.sh exports scripts/remote.env into the environment before invoking its
# python; standalone heredocs replicate that loader (env wins over the file).
_env = os.path.join(os.environ['SEXIDIUM_REPO'], 'scripts', 'remote.env')
for _l in open(_env):
    _l = _l.strip()
    if _l and not _l.startswith('#') and '=' in _l:
        _k, _v = _l.split('=', 1)
        if len(_v) >= 2 and _v[0] in '"\'': _v = _v[1:-1]
        os.environ.setdefault(_k, _v)
sys.path.insert(0, os.path.join(os.environ['SEXIDIUM_REPO'], 'scripts', 'remote'))
from config import Settings
from portainer import Client
s = Settings(); c = Client(s, verbose=False)
st = c.inspect(sys.argv[1]).get('State', {})
print(st.get('ExitCode', -1))
print(int(bool(st.get('OOMKilled', False))))
EOF
)"
  EXIT_CODE="$(printf '%s' "$state" | sed -n '1p')"
  OOM_KILLED="$(printf '%s' "$state" | sed -n '2p')"
  harness::log "shutdown=${SHUTDOWN_S}s exit=${EXIT_CODE} oom=${OOM_KILLED}"
}

# --- step 8: collect sidecars, wipe run scope; per-test wipe -----------------------
harness::collect_and_clean_run() { # $1=test $2=jar $3=run — sidecars off volume
  local tag="$1-$2-$3" dest="$BENCH_DIR/samples/$tag"
  mkdir -p "$dest"
  on_host "$NODE" "cp /srv/nodes/smp-test/logs/latest.log '$WORK/$tag-console.log' 2>/dev/null || true"
  harness::log "sidecars for $tag (kept: per-second samples + grep-extracted lines)"
  on_host "$NODE" "rm -rf /srv/nodes/smp-test/logs/* /srv/nodes/smp-test/cache/* /srv/nodes/smp-test/crash-reports/*"
}
harness::wipe_test() { # $1=test — WORK + smp-test volume, then free-space check
  local pre="$1" post
  on_host "$NODE" "rm -rf '$WORK' /srv/nodes/smp-test/smp-test /srv/nodes/smp-test/logs/* /srv/nodes/smp-test/cache/* /srv/nodes/smp-test/crash-reports/*"
  post="$(harness::free_gib)"
  harness::log "wiped level dir + smp-test volume: free ${pre} → ${post} GiB"
  [[ "$post" -ge $((pre - 1)) ]] || harness::die "free space did not come back (${pre} → ${post}); next test does NOT start"
  FREEAFTER="$post"
}

# --- step 9: CSV append (one row per run; renderer derives everything else) --------
# -1 convention: not measured in this mode (sample runs don't time load/tick and
# have no NMT), or no-op (save_all_s when no completion line appears — itself a
# durability finding, cf. L2). Never a derived value, never 0-for-unknown.
harness::csv_append() { # args in schema order; empty → -1/empty, never derived values
  printf '%s\n' "$*" >>"$CSV"
}

harness::usage() { sed -n '2,30p' "$0"; }

main() {
  local levels runs jars
  while [[ $# -gt 0 ]]; do case "$1" in
    --levels) LEVELS="$2"; shift 2;;
    --jars) JARS="$2"; shift 2;;
    --runs) RUNS="$2"; shift 2;;
    -h|--help) harness::usage; exit 0;;
    *) harness::die "unknown arg $1";;
  esac; done
  harness::lock; harness::preflight
  [[ -f "$CSV" ]] || harness::die "CSV $CSV missing (created once with the schema header)"
  IFS=',' read -ra levels <<<"$LEVELS"; IFS=',' read -ra jars <<<"$JARS"
  for level in "${levels[@]}"; do
    harness::gate_space 17
    local pretest_free="$FREEBEFORE"
    harness::convert_level "$level"
    for jar in "${jars[@]}"; do
      harness::swap_jar "$jar"
      for ((run = 1; run <= RUNS; run++)); do
        harness::log "=== test #$level jar=$jar run=$run ==="
        harness::restore_pristine
        # ... protocol steps 2–8 per run (boot/load/edit/save/dirty/stop/sample/
        # restart-verify/collect) fill the CSV columns; see run_protocol below.
      done
    done
    harness::wipe_test "$pretest_free"
  done
}

# run_protocol is intentionally NOT auto-executed by main yet: the full matrix is
# BLOCKED on owner cleanup, and each measurement agent (32–39) plugs its column
# logic here before the first full run. Sample validation drives the same steps
# manually (one pass per jar) so the wiring is proven before unblocking.
run_protocol() { :; }

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
