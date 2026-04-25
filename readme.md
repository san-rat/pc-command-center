# PC Command Center

A lightweight Bash-based terminal dashboard for monitoring basic Linux PC status.

The dashboard refreshes on a timer and shows system, network, and process
information in one terminal view.

## Features

- Current user, hostname, date/time, and uptime
- CPU usage
- RAM usage
- Root disk usage
- CPU/system temperature when available
- Active IPv4 network interfaces
- Default gateway
- Top processes sorted by CPU usage

## Requirements

This project is designed for Ubuntu/Linux systems and uses common command-line
tools that are usually available by default:

- `bash`
- `awk`
- `free`
- `df`
- `ip`
- `ps`
- `uptime`

Optional:

- `lm-sensors` for better temperature readings through the `sensors` command

## Usage

Make sure the script is executable:

```bash
chmod +x pc-command-center.sh
```

Run the dashboard:

```bash
./pc-command-center.sh
```

Press `Ctrl + C` to exit.

## Refresh Behavior

The current version clears and redraws the terminal every 60 seconds. This keeps
the implementation simple and easy to understand, but it is not a true realtime
interface.

## Notes

Temperature support depends on the hardware and available Linux sensors. If no
temperature source is detected, the dashboard will show `Not available`.
