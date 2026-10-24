# PC Command Center

PC Command Center is a lightweight Bash terminal dashboard for monitoring the
basic status of an Ubuntu/Linux machine.

The dashboard runs as a compact terminal TUI. It is optimized for small
quarter-screen terminal windows and uses cursor positioning to update in place
instead of clearing and repainting the whole screen on every refresh.

## Features

- Compact terminal view for system usage, health, network status, and top processes
- Current user, hostname, date/time, and uptime
- Total and per-core CPU usage calculated from `/proc/stat` deltas (per-core bars in wide view)
- RAM usage from `free`
- Selected filesystem usage from `df` (root by default)
- Load average from `/proc/loadavg`
- Process count from `ps`
- Swap usage from `free`
- Selected filesystem free space from `df`
- CPU/system temperature when available
- Active IPv4 network interfaces and RX/TX throughput from `/proc/net/dev` counter deltas
- Default gateway
- Live top processes sorted by interval CPU usage; one-shot snapshots label `ps` lifetime averages as AVG
- Battery charge and charging state when a battery is present (wide view)
- Status colors for healthy, warning, and high-usage values
- Responsive compact, mini, micro, and tiny views for smaller terminals
- Live controls for process sorting, pause/resume, help, and network interface selection
- Optional one-shot output mode for quick checks or scripts
- Optional wide layout for larger terminal windows
- Optional configuration for refresh, colors, thresholds, filesystem, interface, and layout

## Requirements

This project is designed for Ubuntu/Linux systems and uses common command-line
tools that are usually available by default. Live telemetry reads `/proc/stat`, `/proc/net/dev`, `/proc/[pid]/stat`, and optional `/sys/class/power_supply` battery files:

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
- `sort`
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
./pc-command-center.sh --layout mini
./pc-command-center.sh --disk /home
./pc-command-center.sh --help
./pc-command-center.sh --version
```

- `--interval SECONDS` sets the live refresh interval (1-999999 seconds).
- `--no-color` disables terminal colors.
- `--once` prints one dashboard snapshot and exits; it takes ~0.25s so CPU% can be measured over a short sampling window.
- `--layout compact|mini|micro|tiny|wide` forces a layout regardless of terminal dimensions. Forced layouts may require more space than a very small terminal provides.
- `--wide` is an alias for `--layout wide`.
- `--disk PATH` monitors the filesystem containing an existing directory. Paths with spaces must be quoted. The default is `/`.
- `--help` shows usage information.
- `--version` prints the current version and exits.

### Configuration

The optional config file is `~/.config/pc-command-center.conf`. When
`XDG_CONFIG_HOME` is set, the file is read from that directory instead.
Precedence is **defaults < config < CLI flags**; repeated CLI options use the last
value. Config is read once at startup.

Use one `KEY=value` entry per line. Blank lines and lines starting with `#` are
ignored. Spaces around keys/values and matching outer single or double quotes
are supported. Values are literal: no variable expansion, command substitution,
escape processing, or inline comments. The last valid entry for a key wins.
Invalid entries print one warning and are ignored; the dashboard keeps running.

```ini
REFRESH_INTERVAL=3
ENABLE_COLOR=1
DISK_PATH=/
NETWORK_INTERFACE=
LAYOUT=auto
CPU_WARN=60
CPU_CRIT=85
RAM_WARN=75
RAM_CRIT=90
DISK_WARN=75
DISK_CRIT=90
TEMP_WARN=70
TEMP_CRIT=85
LOAD_WARN=70
LOAD_CRIT=100
SWAP_WARN=50
SWAP_CRIT=80
```

| Key | Allowed values | Default |
|---|---|---|
| `REFRESH_INTERVAL` | Integer, 1–999999 seconds | `5` |
| `ENABLE_COLOR` | `0` off, `1` on when the terminal supports color | `1` |
| `DISK_PATH` | One existing directory; all disk fields refer to its filesystem | `/` |
| `NETWORK_INTERFACE` | Existing interface name; empty lists all active IPv4 interfaces | Empty |
| `LAYOUT` | `auto`, `compact`, `mini`, `micro`, `tiny`, `wide` | `auto` |
| `CPU_WARN`, `CPU_CRIT` | Integer percentage, 0–100 | `60`, `85` |
| `RAM_WARN`, `RAM_CRIT` | Integer percentage, 0–100 | `75`, `90` |
| `DISK_WARN`, `DISK_CRIT` | Integer percentage, 0–100 | `75`, `90` |
| `TEMP_WARN`, `TEMP_CRIT` | Integer degrees Celsius, 0–999 | `70`, `85` |
| `LOAD_WARN`, `LOAD_CRIT` | Integer percentage of online CPU capacity, 0–999999 | `70`, `100` |
| `SWAP_WARN`, `SWAP_CRIT` | Integer percentage, 0–100 | `50`, `80` |

Each warning threshold must be lower than its critical threshold. Pairs are
validated after reading the whole file, so either order works. An invalid pair
produces one warning and both overrides are ignored. If only one threshold is
specified, it is checked against the other threshold's default.

Setting `NETWORK_INTERFACE` filters both the displayed IPv4 addresses and the
default route to that interface. If it has no active global IPv4 address or
default route, the corresponding field shows unavailable data. Non-root disk
selection uses the `DISK` free-space label instead of `ROOT`.

### Live Controls

- `q` quits and restores the terminal state.
- `r` refreshes immediately.
- `+` makes the dashboard refresh faster, down to 1 second.
- `-` makes the dashboard refresh slower.
- `c` sorts the live process list by interval CPU; `m` sorts by memory.
- `p` pauses or resumes automatic refresh; input remains active while paused.
- `?` shows the key list; any key dismisses it and redraws the dashboard.
- `n` cycles the selected network interface when more than one is active.

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
- Very tiny terminals fall back to CPU, RAM, disk, and abbreviated controls.

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

The current version is **2.1.0**. Runtime requirements are unchanged; Bats and
ShellCheck are development tools only. On Ubuntu, install them and run:

```bash
sudo apt install bats shellcheck
bash -n pc-command-center.sh
shellcheck pc-command-center.sh
bats tests
```

GitHub Actions runs these syntax, lint, and regression checks on pushes and pull
requests. The tests cover formatting, CPU delta math, temperature/process parsing,
CLI validation, layout routing boundaries, telemetry deltas, and snapshots of all five layouts.
Snapshot tests check layout properties rather than changing live metric values.
Additional checks cover consecutive CPU samples, one collection per source per
frame, absent data, cached terminal dimensions, and refresh-key scheduling.
Configuration checks cover every key, validation, literal parsing, CLI precedence,
forced layouts, disk paths, and interface-specific routes.
The script can also be sourced to test functions without launching the dashboard.

Project planning notes are kept locally in the ignored `doc/` directory.
See the [changelog](CHANGELOG.md) for user-facing release history.

The next planned stage is **v3.0**: installable packaging and release artifacts.

## License

[MIT](LICENSE). Copyright (c) 2026 san-rat.
