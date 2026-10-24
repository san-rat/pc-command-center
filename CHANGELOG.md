# Changelog

## 4.0.0 — 2026-10-24

- Add bounded session history, sustained warnings, recovery hysteresis, and recent events.
- Separate metric sampling from terminal repainting and mark missing or warming data explicitly.
- Add focused process, storage, network, and pressure views with keyboard navigation.
- Add literal process filtering, stable PID/start-time selection, and read-only process details.
- Add multiple filesystem capacity/inode selections, explicit block-device I/O rates, and optional Linux pressure data.
- Add versioned JSON/CSV snapshots and opt-in, bounded CSV recording to a new private file.
- Preserve the Bash runtime, compact overview, and existing installation/package format.

## 3.0.0 — 2026-10-24

- Add source install and uninstall targets for `pcc` and a committed manual page.
- Add Debian package creation and tag-triggered GitHub Release automation.
- Document package dependencies, installation, removal, and release steps.

## 2.1.0 — 2026-10-24

- Add live CPU/memory process sorting, pause/resume, a dismissible help overlay, and network-interface cycling.
- Show paused state and update controls in responsive layouts.
- Keep keyboard input active while refresh is paused.

## 2.0.0 — 2026-10-24

- Add RX/TX throughput for the preferred or default-route interface.
- Rank live processes by CPU jiffy deltas and exclude the dashboard itself; one-shot snapshots label lifetime averages as AVG.
- Show battery status when present and per-core CPU bars in the wide layout.
- Degrade missing telemetry sources cleanly and extend the regression suite.

## 1.4.0 — 2026-10-24

- Add an optional literal config file for refresh, colors, metric thresholds,
  monitored filesystem, preferred network interface, and layout.
- Add `--layout` and `--disk`; retain `--wide` as a layout alias.
- Apply defaults < config < CLI precedence and warn on invalid config entries.
- Preserve default layouts and add configuration and selection regressions.

## 1.3.0 — 2026-10-24

- Collect metrics once per frame and share them across all layouts.
- Fix CPU baseline updates so live usage reflects consecutive frames.
- Share process-table formatting and terminal-dimension handling.
- Use Bash time and resize signals to eliminate idle subprocess spawning.
- Preserve existing layouts and add collection, fallback, and scheduling tests.

## 1.2.0 — 2026-10-24

- Add `--version` and support sourcing functions without starting the dashboard.
- Add Bats regression tests, ShellCheck cleanup, and GitHub Actions checks.
- Add an MIT license and track project architecture, gaps, roadmap, and work log.
- Refresh documentation to distinguish completed fixes from future plans.

## 1.1 — 2026-07-23

Implemented in commit `aff1799`.

- Correct temperature parsing and process names containing spaces.
- Allow a 0.25s CPU sampling window before the first render.
- Prevent duplicate renders after refresh/speed keys.
- Reject excessively large interval values cleanly.
- Declare missing globals and remove redundant assignments/cursor movement.

## Initial dashboard — April 2026

- System, health, network, and process telemetry.
- In-place refresh, keyboard controls, and one-shot snapshots.
- Quarter-screen compact layout and smaller responsive tiers.
