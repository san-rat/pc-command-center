# Changelog

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
