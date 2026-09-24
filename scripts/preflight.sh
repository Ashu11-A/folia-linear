#!/usr/bin/env bash
# Local preflight mirror of .github/workflows/build.yml.
# Catches staging bugs in seconds that would otherwise cost a 10-minute CI
# round-trip (the last two CI failures were both in this class).
#
# Usage: scripts/preflight.sh [--folia-dir DIR] [--compile] [--tests]
#   default FOLIA_DIR=/tmp/folia-linear/folia (never modified, except --compile/--tests run gradle there)
# Exit 0 = push-ready. Anything else = fix locally, do NOT push.
set -u

SUPPLEMENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FOLIA_DIR=/tmp/folia-linear/folia
DO_COMPILE=0
DO_TESTS=0
for arg in "$@"; do
  case "$arg" in
    --folia-dir) shift_arg=1 ;;
    --compile) DO_COMPILE=1 ;;
    --tests) DO_TESTS=1 ;;
    *)
      if [ "${shift_arg:-0}" = 1 ]; then FOLIA_DIR="$arg"; shift_arg=0; else
        echo "usage: $0 [--folia-dir DIR] [--compile] [--tests]"; exit 2
      fi ;;
  esac
done

pass=0; fail=0
ok()   { echo "PASS: $1"; pass=$((pass+1)); }
nope() { echo "FAIL: $1"; fail=$((fail+1)); }
skip() { echo "SKIP: $1"; }

VERSIONS=$(cd "$SUPPLEMENT_DIR/versions" && ls -d */ 2>/dev/null | tr -d '/' | sort -V)
if [ -z "${VERSIONS:-}" ]; then
  nope "no version folders under versions/"
  echo "---- preflight: $pass passed, $fail failed ----"
  exit 1
fi

# 1. Per-version inventory: every file CI references must exist.
# Version-scoped supplement lives under versions/<branch>/ (pin: upstream.properties).
for v in $VERSIONS; do
  for f in versions/$v/upstream.properties versions/$v/build-hunk.py \
           versions/$v/patches/minecraft-*.patch versions/$v/patches/paper-*.patch \
           versions/$v/tests/LinearRegionFileRoundTripTest.java \
           versions/$v/tests/LinearNmsTestSuite.java versions/$v/tests/LinearTimingInstrumentationTest.java \
           versions/$v/tests/LinearStatsCommandTest.java versions/$v/tests/LinearGlobalConfigTest.java \
           versions/$v/tests/LinearFlushUnlockTest.java versions/$v/tests/LinearEvictionUnlockTest.java \
           versions/$v/tests/LinearMeasurementCountersTest.java; do
    # shellcheck disable=SC2086
    found=$(ls "$SUPPLEMENT_DIR"/$f 2>/dev/null | wc -l)
    [ "$found" -ge 1 ] && ok "inventory $f" || nope "inventory $f (missing)"
  done
  # 1b. upstream.properties completeness: CI and build.sh read all four keys.
  for key in FOLIA_REPO FOLIA_BRANCH FOLIA_REF MC_VERSION; do
    if grep -qE "^${key}=.+" "$SUPPLEMENT_DIR/versions/$v/upstream.properties" 2>/dev/null; then
      ok "props $v $key"
    else
      nope "props $v $key (missing or empty)"
    fi
  done
done
[ -f "$FOLIA_DIR/folia-server/build.gradle.kts.patch" ] \
  && ok "fork base file present" || nope "fork base file missing ($FOLIA_DIR)"

# 2. Hunk determinism per version: pristine base + script must reproduce the
# working file byte-identically. Only runs for the version FOLIA_DIR is pinned
# at; other versions SKIP (point --folia-dir at their ref for the deep check).
if [ -d "$FOLIA_DIR/.git" ]; then
  HEAD=$(git -C "$FOLIA_DIR" rev-parse HEAD)
  for v in $VERSIONS; do
    WANT=$(grep '^FOLIA_REF=' "$SUPPLEMENT_DIR/versions/$v/upstream.properties" 2>/dev/null | cut -d= -f2-)
    if [ "$HEAD" != "${WANT:-}" ]; then
      skip "$v hunk check (FOLIA_DIR at $HEAD, want ${WANT:-unknown}; use --folia-dir)"
      continue
    fi
    TMPD=$(mktemp -d)
    git -C "$FOLIA_DIR" show HEAD:folia-server/build.gradle.kts.patch > "$TMPD/base.patch" 2>/dev/null \
      && python3 "$SUPPLEMENT_DIR/versions/$v/build-hunk.py" "$TMPD/base.patch" >/dev/null \
      && (diff -q "$TMPD/base.patch" "$FOLIA_DIR/folia-server/build.gradle.kts.patch" >/dev/null \
          && ok "$v hunk reproduces working tree byte-identically" \
          || nope "$v hunk output differs from working tree (script or base drifted)") \
      || nope "$v hunk script failed on pristine base"
    rm -rf "$TMPD"
  done
else
  nope "not a git checkout: $FOLIA_DIR"
fi

# 3. Patch files are non-empty unified diffs, in every version folder.
for v in $VERSIONS; do
  for p in "$SUPPLEMENT_DIR"/versions/$v/patches/*.patch; do
    [ -f "$p" ] || { nope "$v patch set empty"; break; }
    grep -q '^diff --git' "$p" && grep -q '^@@' "$p" \
      && ok "patch parses: $v/$(basename "$p")" \
      || nope "patch malformed: $v/$(basename "$p")"
  done
done

# 4. Inherited-bug grep gates, per version (see docs/architecture.md
# "Inherited bugs that were fixed, not ported"). Scans added patch lines,
# skipping comment-only lines, *Test.java demonstration fixtures (which pin
# the buggy behaviour on purpose), and lines marked BUGGY / // BUG.
bug_gate() { # $1 = version dir, $2 = fixed-string pattern
  awk -v pat="$2" '
    /^\+\+\+ b\// { file=$0; next }
    /^\+/ {
      if (substr($0, 1, 3) == "+++") next
      line = substr($0, 2)
      if (file ~ /Test\.java$/) next
      if (line ~ /^[[:space:]]*(\*|\/\/)/) next
      if (line ~ /[Bb][Uu][Gg][Gg][Yy]/) next
      if (index(line, pat)) print file " :: " line
    }' "$1"/patches/*.patch 2>/dev/null
}
for v in $VERSIONS; do
  if ! ls "$SUPPLEMENT_DIR"/versions/$v/patches/*.patch >/dev/null 2>&1; then
    skip "$v bug gates (no patches)"
    continue
  fi
  for spec in '|| !endsWith#extension predicate always true' \
              'format.equals(#enum-vs-String guard always true' \
              '(linear | mca)#spaced upgrader alternation never matches'; do
    pat="${spec%%#*}"; label="${spec#*#}"
    hits=$(bug_gate "$SUPPLEMENT_DIR/versions/$v" "$pat")
    if [ -z "$hits" ]; then
      ok "$v inherited bug absent: $pat"
    else
      nope "$v inherited bug reappeared ($label): $hits"
    fi
  done
done

# 5. Workflow self-checks (same greps as CI preflight job).
python3 -c "import yaml; yaml.safe_load(open('$SUPPLEMENT_DIR/.github/workflows/build.yml'))" 2>/dev/null \
  && ok "workflow YAML parses" || echo "SKIP: workflow YAML parse (no pyyaml)"
if grep -rn 'folia-paperclip-26\.1\.2-\*' "$SUPPLEMENT_DIR/.github/workflows/build.yml" >/dev/null; then
  nope "over-specific jar glob present (use folia-paperclip-*.jar)"
else
  ok "jar globs generic"
fi
if grep -rnE 'gh release (upload|create|edit|delete)' "$SUPPLEMENT_DIR/.github/workflows/build.yml" | grep -v '\-\-repo' >/dev/null; then
  nope "gh invocation without --repo"
else
  ok "gh invocations carry --repo"
fi

# 6. Opt-in slow gates (need fork gradle env + network).
if [ "$DO_COMPILE" = 1 ]; then
  (cd "$FOLIA_DIR" && ./gradlew :folia-server:compileJava --stacktrace) \
    && ok "fork compileJava" || nope "fork compileJava"
fi
if [ "$DO_TESTS" = 1 ]; then
  (cd "$FOLIA_DIR" && ./gradlew :folia-server:test --tests "net.linear.LinearNmsTestSuite" --stacktrace) \
    && ok "Linear suites green" || nope "Linear suites"
fi

echo "---- preflight: $pass passed, $fail failed ----"
[ "$fail" -eq 0 ]
