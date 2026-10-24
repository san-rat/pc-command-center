# PC Command Center

PC Command Center is a lightweight Bash terminal dashboard for monitoring the
basic status of an Ubuntu/Linux machine.

The dashboard runs as a compact terminal TUI. It is optimized for small
quarter-screen terminal windows and uses cursor positioning to update in place
instead of clearing and repainting the whole screen on every refresh.

## Features

- Compact terminal view for system usage, health, network status, and top processes
- Current user, hostname, date/time, and uptime
- CPU usage calculated from `/proc/stat` deltas between refresh ticks
- RAM usage from `free`
- Root disk usage from `df`
- Load average from `/proc/loadavg`
- Process count from `ps`
- Swap usage from `free`
- Root disk free space from `df`
- CPU/system temperature when available
- Active IPv4 network interfaces
- Default gateway
- Top processes sorted by CPU usage
- Status colors for healthy, warning, and high-usage values
- Responsive compact, mini, micro, and tiny views for smaller terminals
- Keyboard controls for quitting, refreshing, and changing refresh speed
- Optional one-shot output mode for quick checks or scripts
- Optional wide layout for larger terminal windows

## Requirements

This project is designed for Ubuntu/Linux systems and uses common command-line
tools that are usually available by default:

- `bash`
- `awk`
- `cat`
- `date`
- `df`
- `free`
- `getconf`
- `grep`
- `head`
- `hostname`
- `ip`
- `ps`
- `sed`
- `stty`
- `tput`
- `uptime`
- `whoami`

Optional:

- `lm-sensors` for better temperature readings through the `sensors` command

## Installation

Clone or download the project, then make the script executable:

```bash
chmod +x pc-command-center.sh
```

If you want temperature readings from `lm-sensors`, install and configure it:

```bash
sudo apt update
sudo apt install lm-sensors
sudo sensors-detect
```

## Usage

Run the dashboard from the project directory:

```bash
./pc-command-center.sh
```

The default refresh interval is 5 seconds.

### Options

```bash
./pc-command-center.sh --interval 3
./pc-command-center.sh --no-color
./pc-command-center.sh --once
./pc-command-center.sh --wide
./pc-command-center.sh --help
./pc-command-center.sh --version
```

- `--interval SECONDS` sets the live refresh interval (1-999999 seconds).
- `--no-color` disables terminal colors.
- `--once` prints one dashboard snapshot and exits; it takes ~0.25s so CPU% can be measured over a short sampling window.
- `--wide` uses the roomier panel layout for larger terminal windows.
- `--help` shows usage information.
- `--version` prints the current version and exits.

### Live Controls

- `q` quits and restores the terminal state.
- `r` refreshes immediately.
- `+` makes the dashboard refresh faster, down to 1 second.
- `-` makes the dashboard refresh slower.

## Refresh Behavior

The live dashboard enters the terminal alternate screen, hides the cursor, and
redraws from the top-left position with `tput`. It restores the terminal when
the app exits.

By default, the dashboard caps its compact rendered width at 88 columns so it
fits well in a 1/4-screen terminal on a 1920x1080 display. The compact view uses
short sections named `SYS`, `HLT`, `NET`, and `TOP`. The `HLT` section shows
load average, process count, swap usage, and root disk free space.

When the terminal shrinks below the compact target, the dashboard switches
automatically:

- `COMPACT` keeps system, health, network, and process sections.
- `MINI` keeps core system health, swap/root free space, and one top process.
- `MICRO` keeps CPU, RAM, disk, temperature, load, swap, and short controls.
- Very tiny terminals fall back to CPU, RAM, disk, and `q/r`.

The live dashboard reads terminal dimensions at startup and after a window resize
signal (`SIGWINCH`). Idle ticks use Bash's built-in clock and spawn no subprocesses.
Use `--wide` when you want the larger panel layout.

CPU usage no longer waits for a blocking 1-second sample inside each refresh.
Instead, the script stores the previous `/proc/stat` counters and calculates
usage from the difference between dashboard refreshes.
Each frame collects metrics once and shares the values across its panels. RAM and
swap share one `free` call; process count and top processes share one `ps` snapshot.

## Notes

- Temperature support depends on the hardware and available Linux sensors.
- If no temperature source is detected, the dashboard shows `Not available`.
- Network output lists up to 4 active IPv4 interfaces.
- When stdout or stdin is not interactive, the script falls back to one-shot
  output.
- The script is intended for interactive terminal use, not background service
  monitoring.

## Development and project direction

The current version is **1.3.0**. Runtime requirements are unchanged; Bats and
ShellCheck are development tools only. On Ubuntu, install them and run:

```bash
sudo apt install bats shellcheck
bash -n pc-command-center.sh
shellcheck pc-command-center.sh
bats tests
```

GitHub Actions runs these syntax, lint, and regression checks on pushes and pull
requests. The tests cover formatting, CPU delta math, temperature/process parsing,
CLI validation, layout routing boundaries, and snapshots of all five layouts.
Snapshot tests check layout properties rather than changing live metric values.
Additional checks cover consecutive CPU samples, one collection per source per
frame, absent data, cached terminal dimensions, and refresh-key scheduling.
The script can also be sourced to test functions without launching the dashboard.

Project documentation is kept in Git:

- [Project overview](doc/PROJECT.md): architecture and design constraints.
- [Roadmap](doc/ROADMAP.md): completed stages, future specs, and acceptance criteria.
- [Known gaps](doc/GAPS.md): original audit with current resolution status.
- [Work log](doc/WORKLOG.md): implementation decisions and verification results.
- [Changelog](CHANGELOG.md): user-facing release history.

The next planned stage is **v1.4**: optional configuration and layout/disk flags,
while preserving the default dashboard behavior.

## License

[MIT](LICENSE). Copyright (c) 2026 san-rat.
