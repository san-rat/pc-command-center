# PC Command Center

PC Command Center is a lightweight Bash terminal dashboard for monitoring the
basic status of an Ubuntu/Linux machine.

The dashboard runs as a compact terminal TUI. It is optimized for small
quarter-screen terminal windows and uses cursor positioning to update in place
instead of clearing and repainting the whole screen on every refresh.

## Features

- Compact terminal view for system usage, network status, and top processes
- Current user, hostname, date/time, and uptime
- CPU usage calculated from `/proc/stat` deltas between refresh ticks
- RAM usage from `free`
- Root disk usage from `df`
- CPU/system temperature when available
- Active IPv4 network interfaces
- Default gateway
- Top processes sorted by CPU usage
- Status colors for healthy, warning, and high-usage values
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
```

- `--interval SECONDS` sets the live refresh interval. The minimum is 1 second.
- `--no-color` disables terminal colors.
- `--once` prints one dashboard snapshot and exits.
- `--wide` uses the roomier panel layout for larger terminal windows.
- `--help` shows usage information.

### Live Controls

- `q` quits and restores the terminal state.
- `r` refreshes immediately.
- `+` makes the dashboard refresh faster, down to 1 second.
- `-` makes the dashboard refresh slower.

## Refresh Behavior

The live dashboard enters the terminal alternate screen, hides the cursor, and
redraws from the top-left position with `tput`. It restores the terminal when
the app exits.

By default, the dashboard caps its rendered width at 88 columns so it fits well
in a 1/4-screen terminal on a 1920x1080 display. The compact layout adapts to
shorter terminal heights by showing fewer process rows and collapsing network
details onto one line. Use `--wide` when you want the larger panel layout.

CPU usage no longer waits for a blocking 1-second sample inside each refresh.
Instead, the script stores the previous `/proc/stat` counters and calculates
usage from the difference between dashboard refreshes.

## Notes

- Temperature support depends on the hardware and available Linux sensors.
- If no temperature source is detected, the dashboard shows `Not available`.
- Network output lists up to 4 active IPv4 interfaces.
- When stdout or stdin is not interactive, the script falls back to one-shot
  output.
- The script is intended for interactive terminal use, not background service
  monitoring.
