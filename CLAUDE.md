# PC Command Center — contributor guide

Single-file Bash TUI for Ubuntu/Linux. Runtime code is in
`pc-command-center.sh`; current version is 4.1.0. The Makefile supports source
installation, removal, manual generation, and Debian package creation. Project
notes in `doc/` are local and ignored by Git.

## Commands

- Live dashboard: `./pc-command-center.sh` (requires a real TTY).
- Snapshot: `./pc-command-center.sh --once` (also the non-TTY fallback).
- Version: `./pc-command-center.sh --version`.
- Syntax: `bash -n pc-command-center.sh`.
- Lint: `shellcheck pc-command-center.sh`.
- Tests: `bats tests`.
- Development tools on Ubuntu: `sudo apt install bats shellcheck make pandoc dpkg-dev`.
- Headless layout: `TERM= COLUMNS=50 LINES=14 ./pc-command-center.sh --once`.
- Wide alignment: `TERM= COLUMNS=110 LINES=30 ./pc-command-center.sh --once --wide | awk '{print length($0)}' | sort -u` (must print `110`).

GitHub Actions runs syntax, ShellCheck, Bats, and source/package install smoke
checks on push/PR. Tagged releases build and smoke-test the Debian package before
publishing it. Tests source the script using its `BASH_SOURCE` entry guard. They
include synthetic sensor/process
input, CPU deltas, formatting, CLI errors, tier boundaries, and real headless
snapshots. Test tooling is optional for end users.

## Conventions and constraints

- Bash >= 4 and GNU/Linux tools; no macOS compatibility layer.
- `snake_case` functions, local function variables, uppercase globals in the header.
- `collect_sample` publishes a timestamped sample; `collect_metrics` fills `METRIC_*`
  and raw `SAMPLE_VALUE`/`SAMPLE_STATE` fields in the parent shell.
  Renderers only consume those values; do not collect data inside a renderer.
- Share process rows through `format_process_rows`. `read_dimensions` caches
  terminal size in live mode until a `WINCH` signal marks it dirty.
- `read_config` parses known literal settings before `parse_args`; never source
  or evaluate config content. Keep defaults < base config < selected profile < CLI precedence.
- Configure thresholds with the `CPU`, `RAM`, `DISK`, `TEMP`, `LOAD`, and `SWAP`
  `*_WARN`/`*_CRIT` globals. Validate complete pairs after parsing the config.
- Use `tput_cmd` for terminal capabilities and validate numeric output before
  arithmetic; failed terminal queries return an empty string.
- Use `pad_ansi`, `center_ansi`, and `print_fit_line` for width-sensitive output.
  Width calculations count characters, so keep UI glyphs ASCII.
- Colors use `setup_colors` variables and `$RESET`; honor `--no-color`.
- Keep compact width capped at 88 columns. Tier thresholds: compact 60x20,
  mini 45x12, micro 36x8, otherwise tiny. `LAYOUT=auto` selects those tiers;
  `--layout` forces a tier and `--wide` aliases `--layout wide`.
- First render waits 0.25s for a CPU sample. Call `get_cpu_usage` directly so
  `PREV_CPU_*` and per-core baselines advance in the parent shell. Live process CPU
  uses `/proc/[pid]/stat` deltas keyed by PID and start time; one-shot `ps` values are lifetime averages.
- Network throughput uses counter deltas on the preferred/default-route interface;
  `n` cycles available interfaces. Battery data is optional and per-core bars render
  in wide mode.
- History/event arrays are bounded ring buffers. Repaints never append or evaluate.
- Storage batches local `df` under a timeout; remote/FUSE/autofs paths are unsupported.
- JSON/CSV schema 1 percent-encodes text bytes. Recording creates a new 0600 inode
  and atomically links it to the destination; never append or overwrite implicitly.
- Live controls use single-character input. `p` suppresses scheduled frames but not
  input polling; `?` consumes the next key to dismiss help and repaint. `c`/`m`
  choose the process sort metric.
- Schedule with `${EPOCHSECONDS:-$SECONDS}`; never spawn `date` in the idle loop.
- Profile selection is resolved before parsing config; names never contain paths.
  Both layers use the same literal parser. Doctor never starts sampling or a TUI.
- ANSI width checks use `strip_ansi_text` and shared `PLAIN_TEXT`; preserve existing
  SGR-only stripping and ASCII width semantics without spawning sed.
- Optional latency measurements: `python3 tests/latency.py`; no timing thresholds in CI.
- Live repaint uses `cup 0 0` + redraw + `ed`. Do not clear on every refresh.
- Keep terminal setup paired with EXIT cleanup; intentional `tput`/`stty` error
  guards prevent missing terminal capabilities from crashing the dashboard.
- There is deliberately no `set -e`/`set -u`; defaults and guards handle failures.
- Behavior changes must update both `usage()` and lowercase `readme.md`.
- No new required runtime dependencies. Optional sources degrade to N/A.
- Preserve local `.handoff/` evidence and the ignored zero-byte `.codex` artifact.

## Project direction and records

- `doc/PROJECT.md`: architecture and rationale.
- `doc/GAPS.md`: original audit plus current resolution status.
- `doc/ROADMAP.md`: version specs and project roadmap status.
- `doc/WORKLOG.md`: dated implementation and verification record.
- `CHANGELOG.md`: user-facing changes.

Update the work log and roadmap status as work lands. Do not report historical
handoff results as newly run checks. Hosted CI and real-TTY interaction require
separate verification from headless local tests.
