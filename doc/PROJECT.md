# PROJECT.md — PC Command Center

## What this is

PC Command Center is a **single-file Bash terminal dashboard** (`pc-command-center.sh`, ~1,070 lines) that shows live system stats for an Ubuntu/Linux machine: CPU, RAM, disk, temperature, load average, swap, process count, network interfaces/gateway, and the top processes by CPU.

Its defining constraint — visible throughout the git history — is that it must be *glanceable in a quarter-screen terminal on a 1920×1080 display*. It is built for a desktop user who keeps a small terminal tile open in a corner, not for server fleets or background monitoring. Compared to `htop`/`btop`, its value is: zero installation (every dependency ships with Ubuntu), a layout that stays readable down to absurdly small windows, and a `--once` mode for scripts and quick checks.

There is no build system or package manifest. Runtime code remains one executable
script. Version 1.2 adds a Bats test suite, a ShellCheck/CI workflow, an MIT license,
and version-controlled project documentation. See `readme.md` for development
commands and `WORKLOG.md` for verification.

## Tech stack and why

| Piece | Why it was chosen (inferred) |
|---|---|
| Bash ≥ 4 | Zero-install distribution: one `chmod +x` and it runs on any Ubuntu box. Uses `mapfile` and fractional `read -t`, so Bash 4+ is required (macOS's Bash 3.2 will not work). |
| `/proc/stat`, `/proc/loadavg`, `/sys/class/thermal` | Direct kernel interfaces — no polling daemons, no root needed. |
| `free`, `df`, `ps`, `ip`, `uptime` (procps/iproute2) | Preinstalled on the target OS. `ps --sort`, `--no-headers` are GNU-specific — this is deliberately Linux-only. |
| `tput` (terminfo) | Portable cursor control and colors instead of hardcoded escape codes. Every call goes through the `tput_cmd` wrapper so a missing/odd `$TERM` degrades silently instead of crashing. |
| `lm-sensors` (optional) | Better temperature readings when present; falls back to `/sys/class/thermal/thermal_zone0`. |

## Architecture

Everything lives in one file, but it is cleanly layered — functions appear in roughly this order top-to-bottom:

```
                       ┌──────────────────────────────────────────┐
 kernel & CLI sources  │ /proc/stat /proc/loadavg /sys/…/thermal  │
                       │ free · df · ps · ip · uptime · sensors   │
                       └──────────────┬───────────────────────────┘
                                      │ raw text
                       ┌──────────────▼───────────────────────────┐
   collectors          │ get_cpu_usage  get_memory_info/percent   │  one get_* per
                       │ get_disk_info  get_load_*  get_swap_*    │  metric, value
                       │ get_temperature  get_process_count …     │  via stdout
                       └──────────────┬───────────────────────────┘
                                      │ numbers & strings
                       ┌──────────────▼───────────────────────────┐
   formatting          │ strip_ansi  visible_length  pad_ansi     │  ANSI-aware
   primitives          │ center_ansi  bar  colorize  status_color │  width math
                       │ repeat_char  panel  metric_line          │
                       └──────────────┬───────────────────────────┘
                                      │ fixed-width lines
                       ┌──────────────▼───────────────────────────┐
   layout renderers    │ render_wide_dashboard      (--wide)      │  picked by
                       │ render_compact_dashboard   (≥60×20)      │  measured
                       │ render_mini_dashboard      (≥45×12)      │  cols×lines
                       │ render_micro_dashboard     (≥36×8)       │  every frame
                       │ render_tiny_fallback       (anything)    │
                       └──────────────┬───────────────────────────┘
                                      │ routed by render_dashboard
                       ┌──────────────▼───────────────────────────┐
   drivers             │ run_live: 0.1s poll loop — keys, resize, │
                       │           refresh tick, cup 0 0 repaint  │
                       │ --once:   single render to stdout        │
                       └──────────────────────────────────────────┘
```

Data flows one way: kernel/CLI → collectors → formatters → a renderer → stdout. There is no persistent state on disk, no network, no config file. The main cross-frame state includes `PREV_CPU_IDLE`/`PREV_CPU_TOTAL` (CPU delta sampling) and `NEXT_DRAW`/`REFRESH_INTERVAL` (tick scheduling).

`main()` parses args, sets up colors, primes the CPU sample, waits 0.25s, then either renders once or enters `run_live`. Sourcing the file defines functions without running `main`. If stdin or stdout is not a TTY, `run_live` silently degrades to one-shot mode — so piping the script always works.

## Key design decisions

1. **Non-blocking CPU sampling.** CPU% is computed from the delta between the previous and current `/proc/stat` counters (`get_cpu_usage`) instead of the classic "sleep 1 between two reads". The intended sample window is the refresh interval. Current renderers call the collector through command substitution, which loses its state updates: subsequent frames compare against startup counters (gap 13, scheduled for v1.3). The git history shows this replaced an earlier blocking approach. Since v1.1, startup waits 0.25s after priming the counters before the first render. This improves the first sample but is still a short sampling window.

2. **Flicker-free in-place repaint.** Live mode enters the alternate screen (`smcup`), hides the cursor, and each frame moves to `cup 0 0`, redraws, then clears the remainder with `ed` — it never clears the whole screen. This is the repo's core UX contract (commit `9d82370` exists specifically for this).

3. **An ANSI-aware layout layer.** Colored text breaks `printf '%-20s'` padding because escape codes count as characters. The script solves this properly: `strip_ansi`/`visible_length`/`pad_ansi`/`center_ansi` compute *visible* width and pad/truncate accordingly (truncation appends `~`). Every panel border lines up because every line passes through this layer.

4. **Responsive layout tiers, measured every frame.** `render_dashboard` re-reads terminal dimensions and routes to compact/mini/micro/tiny. The live loop also polls dimensions every 0.1s and re-renders on change — resize handling without a `SIGWINCH` trap. `--wide` opts out of the tiers entirely and uses the bordered two-column panel layout.

5. **One polling loop for everything.** `run_live` uses `read -rsn1 -t 0.1` as a combined 100ms sleep + keyboard reader, then checks resize and whether `NEXT_DRAW` has arrived. Simple and signal-free, at the cost of ~10 subprocess spawns per second while idle (`tput cols`/`lines`, `date`).

6. **Degrade, never crash.** `tput_cmd` swallows errors; every optional command is `command -v`-guarded; missing data renders as `Not available`/`N/A`; a zero-swap system, a missing sensor, or a dumb terminal all produce a working dashboard. There is deliberately no `set -e`/`set -u` — resilience is hand-rolled with defaults and `|| true`.

## Critical paths (change with care)

- **`pad_ansi` / `visible_length` / `strip_ansi`** — every rendered line passes through these. A width-math bug breaks every layout at once. Note: they count *characters*, not display cells, so the UI must stay ASCII (an emoji or CJK char would misalign every border).
- **`setup_terminal` / `cleanup` pairing** — `cleanup` restores `stty` state and leaves the alternate screen on EXIT. Break this pairing and the user's terminal is left echo-less and cursor-less.
- **`render_dashboard` routing thresholds** — the 60×20 / 45×12 / 36×8 breakpoints define the product's responsive behavior; readme.md documents them.
- **`get_cpu_usage` state (`PREV_CPU_*`)** — the only sampled-over-time metric; call order matters (`init_cpu_sample` must run before the first render).
- **`tput_cmd`** — the terminal-capability chokepoint. All cursor/color operations must go through it.

**Safe to change casually:** panel row content and ordering, warn/crit color thresholds (the `60 85` / `75 90` style arguments), labels, the process-list row limits, and anything in `readme.md`.

## Things that will trip up someone new

- **The first CPU sample spans 0.25s.** v1.1 added this startup wait; it remains a short snapshot, not a long-term average.
- **`ps` %CPU is a lifetime average**, not "current usage" — freshly spawned processes show inflated values, which is why the dashboard's own `ps` invocation regularly appears as the #1 "top process". That's a semantics artifact, not a parsing bug.
- **`tput_cmd` returns an empty string on failure** — never feed its output into arithmetic without the `[[ =~ ^[0-9]+$ ]]` guard you'll see used everywhere.
- **Help text lives in two hand-synced places**: the `usage()` heredoc and `readme.md`. Behavior changes must update both.
- **The readme is lowercase `readme.md`**, and `.codex` is a local zero-byte editor artifact (untracked, gitignored) — leave both as they are.
- **Live mode needs a real TTY.** In CI/sandboxes the script auto-falls back to one-shot; to exercise layout tiers without a terminal, force dimensions: `TERM= COLUMNS=50 LINES=14 ./pc-command-center.sh --once`.

See **GAPS.md** for the historical audit and resolution status, **ROADMAP.md** for the staged improvement plan, and **WORKLOG.md** for completed work.
