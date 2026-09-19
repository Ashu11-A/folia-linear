#!/usr/bin/env bash
# Local preflight mirror of .github/workflows/build.yml.
# Catches staging bugs in seconds that would otherwise cost a 10-minute CI
# round-trip (the last two CI failures were both in this class).
#
# Usage: scripts/preflight.sh [--folia-dir DIR] [--compile] [--tests]
#   default FOLIA_DIR=/tmp/sexidium-folia/folia (never modified, except --compile/--tests run gradle there)
# Exit 0 = push-ready. Anything else = fix locally, do NOT push.
set -u

SUPPLEMENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FOLIA_DIR=/tmp/sexidium-folia/folia
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

# 1. Inventory: every file CI references must exist.
for f in patches/minecraft-*.patch patches/paper-*.patch tests/LinearRegionFileRoundTripTest.java \
         tests/SexidiumNmsTestSuite.java scripts/apply-deps-hunk.py .github/workflows/build.yml; do
  # shellcheck disable=SC2086
  found=$(ls "$SUPPLEMENT_DIR"/$f 2>/dev/null | wc -l)
  [ "$found" -ge 1 ] && ok "inventory $f" || nope "inventory $f (missing)"
done
[ -f "$FOLIA_DIR/folia-server/build.gradle.kts.patch" ] \
  && ok "fork base file present" || nope "fork base file missing ($FOLIA_DIR)"

# 2. Hunk determinism: pristine base + script must reproduce the working file byte-identically.
if [ -d "$FOLIA_DIR/.git" ]; then
  TMPD=$(mktemp -d)
  git -C "$FOLIA_DIR" show HEAD:folia-server/build.gradle.kts.patch > "$TMPD/base.patch" 2>/dev/null \
    && python3 "$SUPPLEMENT_DIR/scripts/apply-deps-hunk.py" "$TMPD/base.patch" >/dev/null \
    && (diff -q "$TMPD/base.patch" "$FOLIA_DIR/folia-server/build.gradle.kts.patch" >/dev/null \
        && ok "hunk reproduces working tree byte-identically" \
        || nope "hunk output differs from working tree (script or base drifted)") \
    || nope "hunk script failed on pristine base"
  rm -rf "$TMPD"
else
  nope "not a git checkout: $FOLIA_DIR"
fi

# 3. Patch files are non-empty unified diffs.
for p in "$SUPPLEMENT_DIR"/patches/*.patch; do
  grep -q '^diff --git' "$p" && grep -q '^@@' "$p" \
    && ok "patch parses: $(basename "$p")" \
    || nope "patch malformed: $(basename "$p")"
done

# 4. Workflow self-checks (same greps as CI preflight job).
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

# 5. Opt-in slow gates (need fork gradle env + network).
if [ "$DO_COMPILE" = 1 ]; then
  (cd "$FOLIA_DIR" && ./gradlew :folia-server:compileJava --stacktrace) \
    && ok "fork compileJava" || nope "fork compileJava"
fi
if [ "$DO_TESTS" = 1 ]; then
  (cd "$FOLIA_DIR" && ./gradlew :folia-server:test --tests "net.sexidium.SexidiumNmsTestSuite" --stacktrace) \
    && ok "Linear suites green" || nope "Linear suites"
fi

echo "---- preflight: $pass passed, $fail failed ----"
[ "$fail" -eq 0 ]
