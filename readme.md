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

### Install from source

Clone the project and install it for your user:

```bash
make install
pcc --version
man pcc
```

By default, `make install` places `pcc` in `~/.local/bin` and its manual in
`~/.local/share/man/man1`. Add `~/.local/bin` to `PATH` if it is not already
there. To install system-wide, run `sudo make install PREFIX=/usr`. Remove a
source installation with `make uninstall`, using the same `PREFIX` and `DESTDIR`
values used during installation.

### Install a Debian package

Download the `.deb` attached to a project release and install it with:

```bash
sudo dpkg -i ./pc-command-center_VERSION_all.deb
pcc --version
man pcc
```

Remove the package with `sudo dpkg -r pc-command-center`.

### Build from source

The committed `pc-command-center.1` documents the command-line options and live
controls. Regenerate it from this README with `make man` (requires `pandoc`).
Build a Debian package with `make package` (requires `dpkg-deb`); the artifact is
written to `dist/`.
Maintainers publish a version by pushing a `vX.Y.Z` tag matching the script
version. GitHub Actions runs the checks, builds and smoke-tests the `.deb`, then
attaches it to a GitHub Release with notes from `CHANGELOG.md`.

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
- `--profile NAME` selects a named configuration profile.
- `--list-profiles` lists available profile names and exits.
- `--doctor` reports dependencies, source capabilities, and configuration diagnostics.
- `--version` prints the current version and exits.

### Configuration

The optional config file is `~/.config/pc-command-center.conf`. When
`XDG_CONFIG_HOME` is set, the file is read from that directory instead.
Precedence is **defaults < base config < selected profile < CLI flags**; repeated CLI options use the last
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

### Named configuration profiles

Use profiles to switch between configurations without editing the base file:

```bash
pcc --list-profiles
pcc --profile daily
pcc --profile development --interval 3
pcc --profile low-power
```

Profiles are optional literal `KEY=value` files under
`~/.config/pc-command-center/profiles/NAME.conf`, or
`$XDG_CONFIG_HOME/pc-command-center/profiles/NAME.conf` when that variable is set.
Names contain 1–64 ASCII letters, digits, underscores, or hyphens and must start
with a letter or digit. Dots, slashes, whitespace, and path traversal are rejected.
A selected profile must be a readable regular file; a missing profile is an error.
No profile is selected automatically.

Precedence is **defaults < base config < selected profile < CLI flags**. Profile
selection is resolved before loading files, so CLI flags win regardless of where
`--profile` appears. Repeated `--profile` options select the last name. Profiles use
exactly the same allowed keys, quoting, validation, and literal parsing as the base
config; they cannot execute commands, include files, or select another profile.
Threshold pairs are validated per layer against inherited values. An invalid pair
in a profile keeps the inherited pair. Indexed `WATCH_DISK_1` … `WATCH_DISK_8` keys
override those individual entries; the first CLI `--watch-disk` still replaces the
whole extra-filesystem selection.

Three editable examples are included in `examples/profiles/` and installed under
`PREFIX/share/doc/pc-command-center/examples/profiles/` (the Debian package uses
`/usr/share/doc/pc-command-center/examples/profiles/`). They are not automatically
copied into your configuration directory:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/pc-command-center/profiles"
cp examples/profiles/*.conf "${XDG_CONFIG_HOME:-$HOME/.config}/pc-command-center/profiles/"
# For a Debian installation, copy from /usr/share/doc/pc-command-center/examples/profiles/ instead.
```

`daily` uses the normal five-second interval and automatic layout. `development`
uses a two-second interval, wide layout, and longer history. `low-power` reduces
monitoring frequency to 15 seconds and disables history/pressure collection; it is
an overhead-reduction preset, not a measured battery-saving guarantee. Settings
not specified in a profile inherit the base config/defaults.

### Diagnose unavailable readings

```bash
pcc --doctor
pcc --doctor --profile development
pcc --doctor --disk /home --device nvme0n1
```

`--doctor` prints a read-only report and exits without starting the TUI, priming
CPU sampling, recording, or writing configuration. It checks required commands,
configuration warnings and effective settings, terminal capabilities, procfs,
memory/process tools, selected filesystem/inode support, explicit block-device
counters, IPv4 availability, temperature sources, battery, and optional pressure.
Each result includes a reason or practical next step when a capability is limited.
Command probes have a two-second timeout plus a one-second termination grace;
several slow probes can therefore make the complete report take longer. No install,
repair, privileged probe, or sensor-configuration command runs automatically.

`OK` means available, `INFO` explains an expected condition, `WARN` identifies a
limited or optional capability, and `FAIL` identifies a missing required command.
The exit status is 1 if a required command is missing, otherwise 0; optional missing
hardware and ignored configuration entries remain warnings. Argument/profile errors
also exit 1. A successful diagnostic does not guarantee that every per-process file
is readable or that a device remains connected. Throughput still needs two samples.
`--doctor` cannot be combined with JSON/CSV output or recording.

### Responsiveness and measurement

Width calculations now strip SGR color codes using Bash builtins, and fitted-line
rendering avoids a command substitution per line. This reduces cached repaint and
navigation overhead while preserving existing output, sample publication, rate
baselines, history, and recording behavior. Pressure file reads also avoid `cat`
subprocesses. Sampling remains synchronous: process scans and bounded filesystem
probes can still delay input. Repainting does not collect a new sample.

For repeatable collection, cached-render/handler, and real terminal key-to-frame
measurements, run the optional development-only harness:

```bash
python3 tests/latency.py
python3 tests/latency.py --script /path/to/baseline.sh --samples 7
```

This uses Python's standard library, live host data, and a Linux PTY. Results vary
with process count, host load, terminal size, and selected resources; no universal
latency limit is asserted. See [measured results and method](docs/PERFORMANCE.md).

### Live Controls

- `q` quits and restores the terminal state.
- `r` refreshes immediately.
- `+` makes the dashboard refresh faster, down to 1 second.
- `-` makes the dashboard refresh slower.
- `c` sorts the live process list by interval CPU; `m` sorts by memory.
- `p` pauses or resumes automatic refresh; input remains active while paused.
- `?` shows the key list; any key dismisses it and redraws the dashboard.
- `n` cycles the selected network interface when more than one is active.
- `1`–`5` select focused views; `e` toggles events.
- `j`/`k` navigate lists; `/`, Enter, Escape, and `a` operate process filtering/details.

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
Each sampling cycle collects metrics once and shares values across all views.
Repainting a view does not collect a sample. RAM and
swap share one `free` call; process count and top processes share one `ps` snapshot.

## History, warnings, and investigation

Version 4.0 keeps the Bash terminal interface and adds session history, sustained
warnings, focused views, read-only process exploration, storage/device monitoring,
Linux pressure information, and explicit export/recording. No background service or
new runtime package is required. The extra filesystem and recording operations use
utilities from the existing coreutils dependency (`timeout`, `mktemp`, `ln`, `rm`).

### Sampling and history

A sample is one collection cycle. Resize, sorting, view changes, scrolling, help
dismissal, and interval changes repaint the latest sample without reading sources
again. `r` requests a sample; requests within the clock resolution are coalesced.
Elapsed measurement time comes from `/proc/uptime`, while displayed timestamps use
UTC. CPU/network/device baselines live in the parent shell.

Wide Overview and Network show CPU, RAM, RX, and TX history. History is retained in
memory for this session only. The default is 60 samples, configurable from 10 to
600. Each character represents a sample, not a fixed time bucket. The caption
shows the actual elapsed span and visible sample count, so changing the refresh
interval does not mislabel the graph.

The intensity alphabet is `._:-=+*#%@`, from low to high. CPU and RAM use 0–100%
scales. RX and TX share the displayed network peak. `?` means missing/warming data;
`|` marks a sampling discontinuity. A measured zero is `.`, never a missing point.
Changing network interfaces invalidates the old network points while retaining
CPU and RAM history. Smaller overview layouts retain their compact numeric display.

Pause and help suspend automatic sampling. Manual refresh works while paused.
Resuming or crossing a long sample gap re-primes rate baselines; the first affected
CPU/network/device value may be `N/A` or warming. Unobserved time does not count
as evidence that a warning condition persisted. An unavailable source never
becomes a healthy zero in exported data.

### Sustained warnings and recent events

The existing warning/critical thresholds now also drive session warnings for CPU,
RAM, the primary filesystem, temperature, normalized load, and swap. A threshold
must be met or exceeded for 30 seconds of sufficiently frequent observations by
default. Critical escalation has its own confirmation period. Recovery requires
15 seconds below the recovery boundary, with a default margin of five percentage
points (five degrees Celsius for temperature). Normalized-load margins are in
percentage points of online CPU capacity.

A gap longer than twice the configured interval resets pending confirmation.
Sparse sampling can confirm a condition only when the next observation arrives;
a 30-second threshold cannot be confirmed at 30 seconds with a 60-second interval.
Missing data retains an active warning as stale and requires fresh evidence on
return. Critical conditions downgrade to warning before clearing when appropriate.

Press `e` to inspect recent transitions; `j`/`k` scroll and `e` closes the list.
The default capacity is 100 events, bounded to 10–1000. Repeated observations of
an unchanged state do not create events. Overview displays the most severe warning
and active count; small headings show `[!]` when an alert is active. `[REC!]` marks
recording failure. One-shot snapshots do not claim a sustained warning history.

### Focused views and process details

Use `1` Overview, `2` Processes, `3` Storage, `4` Network, and `5` Pressure. Each view
fits the available terminal; `--view` selects the startup view. `?` lists controls.

In Processes, `j`/`k` move selection, `c`/`m` sort by CPU/memory, and `/` opens a
literal, case-insensitive PID/name filter. Enter applies the filter, Escape cancels,
and backspace edits. Clear the filter text to show all processes. Filter characters
are never shell commands or regular expressions. Input is limited to 128 characters;
`q` typed during filter editing is part of the filter.

Enter opens details for the selected process; Escape returns to the list. Details
include user, state, elapsed lifetime, resident memory, threads, parent PID, CPU,
and memory percentage. Selection follows PID plus kernel start time, so PID reuse
cannot silently transfer a selection or reuse the old CPU baseline. Exited or
unreadable processes are shown as unavailable. CPU follows the existing per-core
convention: one fully used core is 100%, and a multithreaded process may exceed it.
New or reused processes show N/A until an interval baseline exists.
One-shot CPU is explicitly labeled AVG for the `ps` lifetime average.

Full command arguments are off by default. Press `a` in details to enable them;
the next sample, or `r`, reads the selected command line. The display is bounded
and control/non-ASCII bytes are replaced with `?` to preserve ASCII terminal layout.
No process signals, renicing, or other machine-changing actions are provided.

### Filesystems and device throughput

`--disk PATH` remains the primary overview filesystem and retains last-option-wins
semantics. Add up to eight other paths with repeated `--watch-disk PATH` options.
The first CLI `--watch-disk` replaces the configured extra selections. Quote paths
with spaces. Config uses individual `WATCH_DISK_1` through `WATCH_DISK_8` values.

Storage shows capacity, free bytes, and inode usage. Paths on the same filesystem
are grouped by kernel device identity, including bind-mount aliases, which are
listed together. Unavailable inode accounting displays `N/A`. A selected filesystem
that disappears or changes identity is marked unavailable; restart to accept a new
mount identity. Remote/FUSE/autofs selections are marked unsupported instead of
being probed. Local `df` collection is batched and bounded by a two-second timeout
with a one-second termination grace period. A failed batch is unavailable for that
cycle. These synchronous probes can delay input during their bounded execution.

Choose a block device explicitly, for example `--device nvme0n1` (use a device
present on your machine). Its read/write throughput is shown separately from
filesystem capacity. Rates use kernel counters and actual elapsed time; sector
counters are in 512-byte units regardless of hardware sector size. The tool does
not sum disks, partitions, or device-mapper layers and does not automatically map a
filesystem to its physical backing device. Switching/resetting a device warms its
baseline. See the [kernel block-statistics documentation](https://docs.kernel.org/block/stat.html).

### Resource pressure

Pressure shows supported CPU, memory, and I/O `some`/`full` averages over 10, 60,
and 300 seconds. These are percentages of time stalled on resources, not usage
percentages. System-level CPU `full` is undefined and omitted. Missing fields show
`N/A`. Pressure is optional, requires no privilege or new dependency, and has no
automatic alert thresholds. See the [kernel PSI documentation](https://docs.kernel.org/accounting/psi.html).

### Additional configuration

| Key | Default | Allowed values |
|---|---|---|
| `HISTORY_ENABLED` | `1` | `0` or `1` |
| `HISTORY_SAMPLES` | `60` | Integer 10–600 |
| `WARNINGS_ENABLED` | `1` | `0` or `1` |
| `ALERT_TRIGGER_SECONDS` | `30` | Integer 1–3600 |
| `ALERT_RECOVERY_SECONDS` | `15` | Integer 1–3600 |
| `ALERT_PERCENT_MARGIN` | `5` | Integer 0–100 |
| `ALERT_TEMP_MARGIN` | `5` | Integer 0–999 |
| `EVENT_CAPACITY` | `100` | Integer 10–1000 |
| `PRESSURE_ENABLED` | `1` | `0` or `1` |
| `BLOCK_DEVICE` | Empty | Explicit kernel device name; empty disables |
| `WATCH_DISK_1` … `WATCH_DISK_8` | Unset | One existing directory per key |

These settings follow the existing literal parser and precedence rules. Disabling
history does not disable warnings. Disabling warnings does not disable history.
No setting causes history or events to be saved automatically.

## JSON, CSV, and optional recording

```bash
pcc --once --format json
pcc --once --format csv
pcc --wide --record ./session.csv
pcc --view storage --disk / --watch-disk /home --device nvme0n1
```

`--format json` and `--format csv` imply one-shot output and work without a TTY.
`--format terminal` is the default. JSON is one object; CSV is a header plus one
sample row. Both use schema version 1 and raw numeric units. Field names and units:

| Fields | Meaning |
|---|---|
| `schema_version`, `app_version` | Data contract and application versions |
| `session_id`, `sample_sequence` | Session identity and increasing sample number |
| `timestamp_utc`, `elapsed_ms`, `interval_ms` | UTC sample time, elapsed session time, time since prior sample |
| `text_encoding` | `percent-bytes`, described below |
| `disk_path`, `interface` | Primary resource selections |
| `cpu`, `ram`, `swap`, `disk` | Integer percentage values |
| `memory_used_bytes`, `memory_total_bytes` | RAM byte counts |
| `swap_used_bytes`, `swap_total_bytes` | Swap byte counts |
| `disk_used_bytes`, `disk_available_bytes` | Primary filesystem byte counts |
| `rx`, `tx` | Integer bytes per second |
| `temp` | Integer degrees Celsius |
| `<metric>_state` | `valid`, `warming`, `unavailable`, or `unsupported` |

Every numeric metric has a companion state. Unavailable values are JSON `null` or
empty CSV fields. A measured zero remains numeric zero. The first rate sample can
be warming. Multi-filesystem rows, process arguments, hostname, user identity, and
event history are not included in schema 1.

Text fields use reversible percent encoding of bytes. ASCII letters, digits,
underscore, slash, period, colon, and non-leading hyphens remain literal; other
bytes become `%HH`. Decode percent escapes as bytes before interpreting text as
UTF-8. This preserves arbitrary Linux path bytes, prevents terminal control data
from leaking into output, and prevents spreadsheet formulas from appearing at the
start of CSV text fields. JSON/CSV syntax characters are encoded as text data.
The output is ASCII and independent of the numeric locale. For example, a space
is `%20`, a quote is `%22`, a percent sign is `%25`, and a leading `=` is `%3D`.

`--record PATH` requires interactive stdin and stdout and cannot be combined with
one-shot or JSON/CSV output. It creates one new private regular CSV file (mode
0600), never overwrites an existing path, and refuses existing symlinks, directories,
FIFOs, or files. The parent directory must exist and be writable. Publication uses
a private temporary inode and an atomic hard link; the filesystem must support
hard links. There is no append or overwrite mode.

Each completed live sample produces one row. Repaints do not write rows. Pause and
help leave timestamp gaps. Recording stops at 100 MiB or after a write error,
reports the failure in the dashboard, and makes the eventual exit status nonzero;
monitoring continues. A requested recording that cannot start fails before entering
the live dashboard. Descriptors close on normal quit/SIGINT/SIGTERM. Power-loss
persistence and a final row after SIGKILL are not guaranteed.


## Notes

- Temperature support depends on the hardware and available Linux sensors.
- If no temperature source is detected, the dashboard shows `Not available`.
- Network output lists up to 4 active IPv4 interfaces.
- When stdout or stdin is not interactive, the script falls back to one-shot
  output.
- The script is intended for interactive terminal use, not background service
  monitoring.

## Development and project direction

The current version is **4.1.0**. Runtime requirements are unchanged; Bats and
ShellCheck are development tools only. Python 3 is used only by independent
JSON/CSV parser and PTY integration tests. On Ubuntu, install them and run:

```bash
sudo apt install bats shellcheck python3
bash -n pc-command-center.sh
shellcheck pc-command-center.sh
bats tests
```

GitHub Actions runs these syntax, lint, and regression checks on pushes and pull
requests. The tests cover sample/repaint separation, bounded histories, warning transitions,
process identity/filtering, device counters, export parsing, recording failures,
formatting, CPU delta math, temperature/process parsing,
CLI validation, layout routing boundaries, telemetry deltas, and snapshots of all five layouts.
Snapshot tests check layout properties rather than changing live metric values.
Additional checks cover consecutive CPU samples, one collection per source per
frame, absent data, cached terminal dimensions, and refresh-key scheduling.
Configuration checks cover every key, validation, literal parsing, CLI precedence,
forced layouts, disk paths, and interface-specific routes.
The script can also be sourced to test functions without launching the dashboard.

Project planning notes are kept locally in the ignored `doc/` directory.
See the [changelog](CHANGELOG.md) for user-facing release history.

The post-v3 monitoring improvements were introduced in 4.0.0; 4.1.0 adds
responsiveness improvements, diagnostics, and profiles. See the feature and output
contracts above and the changelog for the release scope.

## License

[MIT](LICENSE). Copyright (c) 2026 san-rat.
