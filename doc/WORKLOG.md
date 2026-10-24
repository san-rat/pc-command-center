# Work log

## 2026-10-24 — Hosted CI portability fixes

- Renamed the awk variable `load` to `load_one`: the Ubuntu 26.04 runner rejects
  `load` as a gawk built-in name, while local mawk accepted it.
- Changed the sourceability test to compare traps before and after sourcing,
  rather than assuming the child starts with no ignored signals. It explicitly
  seeds an ignored SIGINT and still checks that functions are defined and sourcing
  emits no output.
- Reproduced the original sourceability failure with Ubuntu 26.04/Bash 5.3.9,
  upstream Bats 1.13.0, and inherited ignored SIGPIPE/SIGQUIT. The old test prints
  those pre-existing traps and fails; the revised test passes in the same shell.
  A temporary script that installs a WINCH trap is still rejected by the new check.
- Enabled `bats --print-output-on-failure` in CI so failed assertions show their
  captured output. No runtime dependencies or layout behavior changed.
- Local syntax and ShellCheck checks passed; all 27 tests passed with Bats 1.13.0
  and mawk. The Ubuntu container's package installation was slow; the source test
  was verified using its base image with upstream Bats mounted read-only.
  Hosted gawk and regression results are tracked on
  [PR #2](https://github.com/san-rat/pc-command-center/pull/2).

## 2026-10-24 — v1.3 single-pass engine

### Changes

- Added parent-shell `collect_metrics` and shared `METRIC_*` values. CPU baselines
  now advance across frames; renderers no longer call collectors.
- Combined memory/swap into one `free -b` parse, preserving human-readable units
  and the previous MiB-based percentage rounding. Disk fields share one `df`,
  process count/table/summary share one `ps`, and IPv4 addresses/default route
  share one `ip -batch` invocation. Load, temperature, uptime, identity, and time
  are collected once per frame.
- Shared the process-table formatter while retaining each layout's spacing.
  Shared validated terminal dimensions between routing and the wide layout.
- Replaced idle `date`/`tput` polling with Bash time and a `WINCH` dirty flag.
  `$SECONDS` is the fallback when `$EPOCHSECONDS` is unavailable. A resize arriving
  during dimension queries remains pending for the next loop iteration.
- Added nine Bats regressions for collection counts across every layout, CPU
  state across rendered frames, shared data, missing sources/zero swap, memory
  units, dimension caching/validation, resize races, and key scheduling.
  Existing v1.2 assertions remain: the process test now seeds the shared snapshot
  from its existing mock, and the routing-only test stubs collection.
- Set version 1.3.0 and updated the contributor guide, README, changelog,
  architecture, gap status, and roadmap. Next implementation stage: v1.4.

### Verification

The `build-test-triager` agent verified the untouched v1.2 baseline: syntax,
ShellCheck, and all 18 Bats tests passed. Child model telemetry was unavailable;
no additional agents were spawned. The main agent reviewed and verified v1.3.

| Check | Result |
|---|---|
| `bash -n pc-command-center.sh` | PASS |
| `/tmp/pcc-v1.2-tools/root/usr/bin/shellcheck pc-command-center.sh` | PASS, no findings |
| `/tmp/pcc-v1.2-tools/root/usr/bin/bats tests` | PASS, 27/27 |
| `git diff --check` | PASS |
| `./pc-command-center.sh --version` | `PC Command Center 1.3.0` |
| `$EPOCHSECONDS` unset; refresh key with `$SECONDS=10`, interval 5 | Next draw scheduled at 15, with no external clock |
| Deterministic fixtures against saved v1.2 script | Byte-identical output at 80x24, 50x14, 40x9, 30x5, and 110x30 wide |
| Linux PTY, `TERM=xterm`, interval 100 | `r`, `+`, `-` each drew once; automatic `SIGWINCH` switched compact → mini → micro → tiny → compact |
| Linux PTY, interval 1 | Scheduled redraw occurred; SIGTERM exited cleanly |
| PTY cleanup after `q` and SIGTERM | Original termios attributes, visible cursor, and original screen restored |

Temporary standard-library Python PTY harnesses and deterministic fixtures live
under `/tmp/pcc-v1.3/`; they add no project/runtime dependency. Fixture commands
provide fixed CPU, memory, disk, load, process, network, temperature, identity,
uptime, and time values before comparing the two scripts' rendered bytes.

Idle measurements used `strace -f -ttt -e trace=process`, an 80x24 PTY,
`--interval 999999 --no-color`, and a two-second window after the first frame
settled. Startup, rendering, and quit were excluded from the counted window:

| Version | Idle seconds | Fork-family calls | `execve` calls |
|---|---:|---:|---:|
| v1.2 | 2.000 | 80 | 48 |
| v1.3 | 2.000 | 0 | 0 |

The idle-spawn reduction exceeds the roadmap's order-of-magnitude target in this
sample. Rendering still launches formatting/source subprocesses; this is not a
claim of zero subprocesses for the whole application.

### Limits

Hosted GitHub Actions has not run for these changes. PTY behavior was checked on
this Linux host with xterm capabilities, not every terminal or Bash 4 installation.
Process CPU remains the `ps` lifetime average (v2.0 work), and temperature source
selection/units remain unchanged. No commit, push, or release was performed.

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
