# Work log

## 2026-10-24 — v1.2 safety net and documentation recovery

### Scope and decisions

Implement the next stage in ROADMAP.md after v1.1, keeping the single-file runtime
and existing layout/telemetry behavior. Preserve the original audit as a historical
record and label resolved gaps rather than deleting their rationale.

### Changes

- Removed the `doc/` ignore rule so architecture, gap audit, roadmap, and this
  work log can be preserved in Git. Updated the existing local `CLAUDE.md`.
- Marked v1.1 complete at `aff1799`, v1.2 implemented, and v1.3 next.
- Added `VERSION=1.2.0`, `--version`, and a `BASH_SOURCE` guard around `main`.
- Added Bats coverage for formatting/ANSI widths, thresholds, bars, CPU deltas,
  sensor formats, all three process formatters, CLI validation, layout boundaries,
  and all five headless snapshots.
- Added GitHub Actions to run syntax checks, ShellCheck, and Bats on push/PR.
- Addressed lint findings by removing unused MAGENTA, using discard fields when
  reading CPU counters, renaming the scalar network row limit, and writing the
  terminal cleanup condition explicitly while retaining its error guard.
- Added MIT LICENSE, with the author identity `san-rat` matching Git metadata.
- Added CHANGELOG.md and development/documentation links in readme.md.

### Verification

Bats 1.10.0 and ShellCheck 0.9.0 were downloaded from the Ubuntu package archive
and extracted under `/tmp/pcc-v1.2-tools`, without installing system packages.

| Check | Command | Result |
|---|---|---|
| Syntax | `bash -n pc-command-center.sh` | PASS |
| Lint | `/tmp/pcc-v1.2-tools/root/usr/bin/shellcheck pc-command-center.sh` | PASS, no findings |
| Regression suite | `/tmp/pcc-v1.2-tools/root/usr/bin/bats tests` | PASS, 18/18 |
| Patch whitespace | `git diff --check` | PASS |
| Mutation check | Restore the original `$2` sensors parser in a temporary copy; run `bats --filter 'sensors parses' tests` there | Expected failure at the Package-format assertion; regression detected |

The `build-test-triager` agent ran the suite and lint/syntax checks. Its model
identifier was not available in telemetry; no additional agents were used.
Main-agent review inspected the source diff and ran the isolated mutation check.
The mutation never touched the working script.

During review, an additional existing CPU-state issue was verified with synthetic
counters: `value=$(get_cpu_usage)` returns 40 for a 100-tick / 60-idle delta, but
leaves caller counters at their old values (100/200 instead of 160/300). Renderer
command substitutions therefore lose the function's counter updates. This is
recorded as gap 13 and added to v1.3, where collection must run in the parent shell;
v1.2 deliberately does not change telemetry behavior.

### Limits and next step

Hosted GitHub Actions has not run for these changes. Headless checks do not
exercise real-terminal keyboard handling or cleanup. No publication or deployment
is part of this work. Next implementation stage: v1.3, after verification passes.

## 2026-07-23 — v1.1 correctness patch (historical)

Commit `aff1799` implements the six v1.1 work items. Existing local evidence in
`.handoff/20260723-v1.1-correctness/` records nine passing checks and zero failures.
Those are historical results, not checks rerun on 2026-10-24. The handoff predates
the commit and says “uncommitted”; Git history confirms the changes were committed
subsequently. The handoff's keypress test inspected scheduling code rather than
exercising real TTY interaction.
