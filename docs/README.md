# Documentation

- [architecture.md](architecture.md) - on-disk format, read and write paths,
  dispatch, flush coordination, concurrency rules, patch inventory, rebase
  surfaces.
- [configuration.md](configuration.md) - every `region-format` key, where it
  goes, how bad values are handled, and the log lines to watch for.
- [benchmarks.md](benchmarks.md) - measured disk savings, compression level 1
  against 22, boot and save numbers, test counts, and what was not measured.
- [observability.md](observability.md) - `/linearstats`, the async flush event,
  the Paper API delegate, and troubleshooting.
- [limitations.md](limitations.md) - what this release does not cover.

Operator-facing material lives in `release/`:

- [../release/OPERATOR-NOTES.md](../release/OPERATOR-NOTES.md) - rollout
  procedure, monitoring, what each log line means.
- [../release/RELEASE.md](../release/RELEASE.md) - version pins, clean-node
  install, knob defaults, dry-run results.
