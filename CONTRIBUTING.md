# Contributing

This repository is a patch supplement, not a full fork checkout. Changes here
are patch files, test sources and tooling that get staged into a pinned Folia
clone at build time.

## Run preflight before pushing

A CI build takes about ten minutes. Most failures so far were staging mistakes
that a local check catches in seconds.

```bash
scripts/preflight.sh            # inventory, hunk determinism, patch parsing, workflow checks
scripts/preflight.sh --compile  # the above, plus fork compileJava
scripts/preflight.sh --tests    # the above, plus the Linear suites
```

- Default `--folia-dir` is `/tmp/sexidium-folia/folia`. Pass your own with
  `scripts/preflight.sh --folia-dir /path/to/folia`.
- `--compile` and `--tests` run Gradle in that directory and need network
  access. The plain run does not.
- Exit code 0 means push-ready. Anything else means fix it locally first.
- The CI `preflight` job runs the same checks; `build` only starts after it
  passes.

## Patch conventions

- `minecraft-*.patch` goes to `folia-server/minecraft-patches/features/`,
  `paper-*.patch` to `folia-server/paper-patches/features/`. Numbering continues
  the base fork's sequence, so a new NMS patch after `minecraft-0012` is
  `minecraft-0013`.
- Filenames are `<area>-<NNNN>-<Subject>.patch`, matching the patch's own
  `Subject:` line.
- Patches apply through paperweight, which uses `git am`. `git am` rejects hunk
  header counts that `git apply` tolerates. Count every body line: `old` is
  space plus minus lines, `new` is space plus plus lines, and a blank context
  line must be a single space, not an empty line. Two CI failures came from
  exactly this.
- Context has to be real context from the target file, not assumed context.
  Several patch headers carry `BASE-TREE ASSUMPTIONS` notes from when the base
  checkout was unavailable; if you touch one of those hunks, verify against the
  actual file.
- Keep the Anvil path byte-identical unless the change is specifically about
  Anvil. Behaviour changes belong behind the `LINEAR` format flag.

## The build-file hunk

`scripts/apply-deps-hunk.py` splices two things into Folia's own
`folia-server/build.gradle.kts.patch`: the `net/sexidium` test source
directory, and the zstd-jni dependency.

- That file uses the paperweight hunk convention, which plain `git apply` cannot
  parse, so the wiring is done by script rather than by a patch.
- The script is deterministic. Preflight proves it by running it against a
  pristine `HEAD` copy and diffing the result against the working file.
- It aborts on upstream drift rather than producing a plausible but wrong file.

## Tests

Test sources in `tests/` are copied into
`folia-server/src/test/java/net/sexidium/` during staging.

- `SexidiumNmsTestSuite.java` is the suite wiring. The fork's Gradle task only
  runs classes matching `**TestSuite`, so a test not reachable from the suite
  never executes.
- New Linear tests need to be added to the suite, not just dropped in the
  directory.
- CI runs `./gradlew :folia-server:test --tests "net.sexidium.SexidiumNmsTestSuite"`
  as a separate gate after the full build.

## CI

`.github/workflows/build.yml`, two jobs.

- `preflight`: clones the pinned base, stages the supplement, and runs the
  workflow self-checks. Minutes, no Gradle. Fails fast on staging bugs.
- `build`: disk guard, Java 25, pinned clone, base-pin check, staging, git
  identity for `git am`, `applyAllPatches`, full build, paperclip jar, Linear
  suites, an Anvil boot smoke and a Linear boot smoke, then artifact upload.

Two self-checks exist because of past breakage and are enforced in both the
workflow and `preflight.sh`:

- No over-specific jar globs. Use `folia-paperclip-*.jar`; the suffix has
  changed before.
- Every `gh release` invocation carries `--repo`.

## Cutting a release

1. Preflight green, then push to `main`.
2. Tag `v26.1.2-linear.N` and push the tag.
3. The tag push triggers the build, which attaches `sexidium-folia-26.1.2.jar`
   and its sha256 to the GitHub release.
4. Update `CHANGELOG.md` in the same change that introduces the behaviour, not
   at tag time.

## Documentation

- `README.md` is the entry point and should stay usable end to end without
  opening anything else.
- `docs/` holds the detail: architecture, configuration, benchmarks,
  observability, limitations.
- `release/` holds operator-facing material and ships with the release package.
- Claims need a source in the repository: a patch, a test, a script, a log
  string or a measurement. If something has not been measured, say so rather
  than estimating.
