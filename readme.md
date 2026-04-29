# PC Command Center

PC Command Center is a lightweight Bash terminal dashboard for monitoring the
basic status of an Ubuntu/Linux machine.

The script clears and redraws one terminal view with system, network, and
process information, making it useful for a quick local health check without
installing a full monitoring stack.

## Features

- Current user, hostname, date/time, and uptime
- CPU usage calculated from `/proc/stat`
- RAM usage from `free`
- Root disk usage from `df`
- CPU/system temperature when available
- Active IPv4 network interfaces
- Default gateway
- Top processes sorted by CPU usage
- Automatic refresh every 5 seconds

## Requirements

This project is designed for Ubuntu/Linux systems and uses common command-line
tools that are usually available by default:

- `bash`
- `awk`
- `cat`
- `clear`
- `date`
- `df`
- `free`
- `grep`
- `head`
- `hostname`
- `ip`
- `ps`
- `sleep`
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

Press `Ctrl + C` to exit.

## Refresh Behavior

The dashboard refreshes every 5 seconds. CPU usage sampling waits for 1 second
inside each refresh cycle so the displayed percentage is based on a short live
measurement rather than a single instant.

## Notes

- Temperature support depends on the hardware and available Linux sensors.
- If no temperature source is detected, the dashboard shows `Not available`.
- Network output lists up to 3 active IPv4 interfaces.
- The script is intended for interactive terminal use, not background service
  monitoring.
