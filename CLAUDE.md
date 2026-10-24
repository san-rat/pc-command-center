# PC Command Center — contributor guide

Single-file Bash TUI for Ubuntu/Linux. Runtime code is in
`pc-command-center.sh`; current version is 1.2.0. No build system or new runtime
dependencies. Project docs in `doc/` are version controlled.

## Commands

- Live dashboard: `./pc-command-center.sh` (requires a real TTY).
- Snapshot: `./pc-command-center.sh --once` (also the non-TTY fallback).
- Version: `./pc-command-center.sh --version`.
- Syntax: `bash -n pc-command-center.sh`.
- Lint: `shellcheck pc-command-center.sh`.
- Tests: `bats tests`.
- Development tools on Ubuntu: `sudo apt install bats shellcheck`.
- Headless layout: `TERM= COLUMNS=50 LINES=14 ./pc-command-center.sh --once`.
- Wide alignment: `TERM= COLUMNS=110 LINES=30 ./pc-command-center.sh --once --wide | awk '{print length($0)}' | sort -u` (must print `110`).

GitHub Actions runs syntax, ShellCheck, and Bats on push/PR. Tests source the
script using its `BASH_SOURCE` entry guard. They include synthetic sensor/process
input, CPU deltas, formatting, CLI errors, tier boundaries, and real headless
snapshots. Test tooling is optional for end users.

## Conventions and constraints

- Bash >= 4 and GNU/Linux tools; no macOS compatibility layer.
- `snake_case` functions, local function variables, uppercase globals in the header.
- `get_*` collectors return data through stdout. Layout refactoring is v1.3 work;
  do not mix it into correctness changes.
- Use `tput_cmd` for terminal capabilities and validate numeric output before
  arithmetic; failed terminal queries return an empty string.
- Use `pad_ansi`, `center_ansi`, and `print_fit_line` for width-sensitive output.
  Width calculations count characters, so keep UI glyphs ASCII.
- Colors use `setup_colors` variables and `$RESET`; honor `--no-color`.
- Keep compact width capped at 88 columns. Tier thresholds: compact 60x20,
  mini 45x12, micro 36x8, otherwise tiny. `--wide` selects the wide layout.
- First render waits 0.25s for a CPU sample. Current command-substitution calls
  lose CPU baseline updates (gap 13); fix parent-shell collection in v1.3.
  `ps` process CPU remains a lifetime
  average; interval sampling is planned for v2.0.
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
- `doc/ROADMAP.md`: version specs; v1.1 complete, v1.2 implemented, v1.3 next.
- `doc/WORKLOG.md`: dated implementation and verification record.
- `CHANGELOG.md`: user-facing changes.

Update the work log and roadmap status as work lands. Do not report historical
handoff results as newly run checks. Hosted CI and real-TTY interaction require
separate verification from headless local tests.
