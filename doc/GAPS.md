# GAPS.md — Known weaknesses, ordered by severity

An audit of `pc-command-center.sh` as of 2026-07-07 (commit `3bcedcf`). Items 1, 2, 4, and 10 were **reproduced empirically**, not just read from the code. Severity scale: **High / Medium / Low**.

## Resolution status (2026-10-24)

This is a **historical audit of `3bcedcf`**, not a list of currently reproduced bugs.
The original findings below are preserved as rationale; their line numbers refer
to that baseline.

| Gap | Current status |
|---|---|
| 1, 2, 4, 10 | Fixed in v1.1 (`aff1799`); parsing regressions covered by v1.2 tests. |
| 3 | v1.2 adds Bats regression tests and a ShellCheck/GitHub Actions workflow. Hosted CI awaits a push. |
| 5 | Open: process CPU is still a lifetime average; interval sampling planned for v2.0. |
| 6, 7 | Addressed in v1.3: one collection per source per frame, shared process formatting, and zero idle subprocesses in a two-second PTY sample. |
| 8 | Addressed in v1.2 with an MIT license. |
| 9 | Open: temperature source selection and unit formatting. v1.3 centralizes absent-temperature display handling while preserving existing labels. |
| 11 | Interval overflow fixed in v1.1; deliberate shell-option and SIGKILL limitations remain documented. |
| 13 | Fixed in v1.3: parent-shell collection advances CPU baselines; consecutive rendered frames are regression-tested. |
| 12 | v1.1 addressed globals/dead code/cursor movement; v1.3 shares dimensions and uptime collection. Help remains hand-synced. |

See [WORKLOG.md](WORKLOG.md) for current verification and limitations.

---

## 1. Temperature parsing is broken for the most common `sensors` output — **High**

**What:** `get_temperature` (pc-command-center.sh:319) runs
`sensors | awk '/Package id 0|Core 0|temp1/ {print $2; exit}'`.
For the standard Intel coretemp lines, `$2` is not the temperature:
`Package id 0:  +42.0°C` → `$2` = `id`; `Core 0:  +40.0°C` → `$2` = `0:`. Only the `temp1:` form works. Verified with representative input: the awk prints `id`.

**Why it matters:** The readme *recommends installing lm-sensors* for better readings — following that advice makes the Temp row display the literal word `id` (with a 0% green bar via `temperature_number` returning 0). The feature breaks precisely on the recommended setup; it only works today because this machine doesn't have `sensors` installed and falls through to `/sys/class/thermal`.

**Fix (single task):** Extract the first numeric temperature from the matched line instead of a field index, e.g. `sensors | grep -Eo -m1 '\+?[0-9]+(\.[0-9]+)?°?C' ...` or in awk match on `/[0-9]+\.[0-9]+°C/` and print the matching token. Add the three sample formats as a test case.

## 2. Process rows corrupt for command names containing spaces — **High**

**What:** Three separately pasted awk blocks parse `ps -eo pid=,comm=,%cpu=,%mem=` by field position: `process_panel` (pc-command-center.sh:486), `compact_process_rows` (pc-command-center.sh:652), `top_process_summary` (pc-command-center.sh:671). `comm` may contain spaces — Firefox's `Isolated Web Co`, `Web Content`, `tmux: server` — which shifts every field. Verified: a `Isolated Web Co` row renders as name `Isolated`, CPU `Web%`, MEM `Co%`.

**Why it matters:** Firefox is the default Ubuntu browser; anyone running it gets garbage in the Top Processes columns of every layout. The data the dashboard exists to display is wrong.

**Fix (single task):** Parse fixed columns from the ends instead of the middle: in awk take `$1` as PID, `$(NF-1)` as CPU, `$NF` as MEM, and everything between as the name (or use `ps -eo pid=,%cpu=,%mem=,comm=` so the space-containing field is last and can be reassembled). Apply to all three sites (ideally after deduplicating them — see gap 7).

## 3. Zero tests, zero lint, zero CI — **High**

**What:** No test files, no shellcheck configuration, no CI workflow exist anywhere in the repo. `shellcheck` isn't even installed on the dev machine.

**Why it matters:** This script has real logic worth protecting: ANSI-aware truncation (`pad_ansi`, pc-command-center.sh:154), CPU delta math (`get_cpu_usage`, pc-command-center.sh:252), layout-tier routing thresholds (`render_dashboard`, pc-command-center.sh:955), argument validation (`parse_args`, pc-command-center.sh:54), and `temperature_number` parsing. Gaps 1 and 2 are exactly the kind of regressions a tiny test suite would have caught. Untested critical paths, specifically: pad/truncate width math, sensors/`ps` output parsing, tier selection at boundary sizes (60×20, 45×12, 36×8), and `--interval` validation.

**Fix (single task):** Add a `tests/` directory using bats-core: source the script with an early-return guard (or split functions into a sourceable file), unit-test the pure functions with canned inputs, plus golden runs of `TERM= COLUMNS=… LINES=… ./pc-command-center.sh --once` asserting every output line has identical width. Add a GitHub Actions workflow running `shellcheck` + `bats`.

## 4. First-frame / `--once` CPU reading is meaningless — **Medium-High**

**What:** `main` (pc-command-center.sh:1056) calls `init_cpu_sample` and renders immediately, so the first `/proc/stat` delta spans only the microseconds of script startup. Verified: `--once` reported 43%, 92%, and 100% on a mostly idle machine across three runs — dominated by the script's own startup burst.

**Why it matters:** `--once` is advertised in the readme "for quick checks or scripts" — and its headline CPU number is noise. In live mode the first displayed frame is equally wrong (self-corrects at the next tick).

**Fix (single task):** In `main`, after `init_cpu_sample`, sleep a short window before the first render (e.g. `sleep 0.25` — Bash 4 `sleep` accepts fractions via coreutils) at least when `ONCE=1`; optionally render live's first frame with CPU shown as `--` until one full interval has elapsed.

## 5. "Top processes" uses lifetime-average %CPU and measures itself — **Medium**

**What:** `ps`'s `%cpu` is cumulative CPU time divided by process lifetime, not current usage. Freshly spawned processes read absurdly high — observed: the dashboard's own `ps` invocation listed as top process at `100%`, and `pc-command-cent` itself appearing in its own list.

**Why it matters:** The panel's implicit promise is "what's hot *right now*"; a long-running compile that finished an hour ago still ranks high, while a fresh spike under-ranks. Self-listing erodes trust in the numbers.

**Fix (single task):** Either document the semantics in readme + panel header ("avg"), filter the script's own PID/children (`$$`, and the `ps` child) out of the listing, or (bigger, defer to ROADMAP v2.0) compute interval deltas from `/proc/[pid]/stat` the same way CPU% already works.

## 6. Event loop spawns ~10+ subprocesses per second while idle — **Medium**

**What:** Every 0.1s iteration of `run_live` (pc-command-center.sh:1031–1053) spawns `tput cols`, `tput lines` (each inside a `$(…)` subshell through `tput_cmd`) and `date +%s`; each render adds ~20 more (`free` ×4, `df` ×2–3, `ps` ×1–2, `ip` ×2, `uptime` ×2, `hostname`, `whoami`, `sed`/`awk` per padded line…).

**Why it matters:** A monitoring tool that generates constant fork/exec churn distorts the very CPU numbers it displays (the `ps` self-listing in gap 5 is a symptom) and wastes battery on laptops.

**Fix (single task):** Replace `date +%s` with Bash's builtin `$SECONDS`/`$EPOCHSECONDS`; check dimensions via `trap … WINCH` + `checkwinsize` (or only poll dimensions once per second, not per 0.1s tick). Keep render-time collection as-is for now (see gap 7 for the bigger consolidation).

## 7. The same metric collection and rendering logic is duplicated across five layouts — **Medium**

**What:** Each renderer independently re-gathers and re-clamps the same data: `system_panel` (pc-command-center.sh:402), `compact_system_rows` (:531), `render_mini_dashboard` (:682), `render_micro_dashboard` (:773), `render_tiny_fallback` (:822) all repeat the cpu/mem/disk/temp collection + `temp_display` + swap-zero handling blocks; the process-table awk is pasted three times (gap 2); the "fetch cols/lines and validate numeric" block appears four times (:896, :946, :1025, :1036); `free` is invoked twice per metric because `get_memory_info` and `get_memory_percent` parse it separately (same for swap).

**Why it matters:** Every metric change or bug fix must be applied in up to five places (gap 2's fix literally needs three edits today). This is the main tax on future work.

**Fix (single task):** Introduce one `collect_metrics()` that runs each source command once per frame and fills globals (`METRIC_CPU`, `METRIC_MEM_PCT`, …); make renderers pure consumers. Add a `read_dimensions()` helper for the cols/lines block. Do this *after* gap 3's tests exist.

## 8. No LICENSE file — **Medium (legal/hardening)**

**What:** The repo has no license, so it defaults to "all rights reserved" despite looking like a shareable open-source utility.

**Why it matters:** Nobody can legally use, package, or contribute to it; distribution-stage plans (ROADMAP v3.0) are blocked on this.

**Fix (single task):** Add a LICENSE file (MIT fits a one-file utility) and mention it in the readme.

## 9. Temperature source and formatting are inconsistent — **Low-Medium**

**What:** The fallback reads only `/sys/class/thermal/thermal_zone0/temp` (pc-command-center.sh:326) — this machine has four zones, and zone0 is whatever enumerated first (often ACPI ambient, not CPU). Units render differently per source (`27C` from sysfs vs `+42.0°C` from sensors, `N/A` vs `Not available` per layout). The raw °C number is also fed into `bar`/`status_color` as if it were a percent.

**Why it matters:** Users can be shown the wrong sensor with no indication, and cosmetic inconsistency leaks the implementation.

**Fix (single task):** Prefer a zone whose `type` is `x86_pkg_temp`/`cpu-thermal` when scanning `/sys/class/thermal/thermal_zone*/`, normalize display to `NN°C`, and keep the 70/85 thresholds (documented as °C thresholds, which is what they effectively are).

## 10. Keypresses cause a double render — **Low**

**What:** `handle_key` (pc-command-center.sh:987–1002) renders and then sets `NEXT_DRAW=$(date +%s)`; the loop immediately sees `now ≥ NEXT_DRAW` and renders *again*. Every `r`/`+`/`-` press paints two frames back-to-back.

**Why it matters:** Wasted work and a subtle CPU-sample distortion (the second frame's delta window is ~0.1s, so its CPU% is noisy — same mechanism as gap 4).

**Fix (single task):** In `handle_key`, set `NEXT_DRAW=$(( $(date +%s) + REFRESH_INTERVAL ))` after rendering, so the loop's next scheduled render is one full interval away.

## 11. Hardening review — mostly clean, three small items — **Low**

Genuinely low risk overall: no network I/O, no file writes, no eval, no privileged operations, no untrusted input interpolated into commands; `parse_args` validates `--interval` strictly; **no secrets found in the repo or history** (scanned; `.gitignore` already excludes `.env*`). Remaining items, each rated:

- **Low:** `--interval 99999999999999999999` leaks a raw Bash error (`[: integer expression expected`, pc-command-center.sh:60) before the clean `die` message — verified. Fix: length-cap the digits in the regex (e.g. `^[0-9]{1,6}$`) or validate with arithmetic in `(( ))` guarded by the regex.
- **Low:** No `set -u`; safety instead relies on hand-written defaults everywhere. Fine as a style choice, but a typo'd variable name silently expands empty. Fix: enable `set -u` and fix the (few) fallout sites, or explicitly document the choice in CLAUDE.md (currently done).
- **Informational:** On SIGKILL the terminal is left in the alternate screen with echo off — unavoidable by design; SIGINT/SIGTERM/EXIT are already handled correctly.

## 12. Small inconsistencies and dead code — **Low**

Bundle of one-line fixes, each safe to do independently:

- `CPU_IDLE`, `CPU_TOTAL` (set in `read_cpu_times`, pc-command-center.sh:242) and `NEXT_DRAW` (:1029) are globals not declared in the header block at :6–14, unlike every other global.
- Dead assignment: `ONCE=1` in the non-TTY fallback of `run_live` (pc-command-center.sh:1015) — nothing reads it afterwards.
- `render_wide_dashboard` repeats the `cup 0 0` that `render_dashboard` already did (pc-command-center.sh:909 vs :951) — harmless duplicate.
- `render_wide_dashboard` re-fetches cols/lines even though `render_dashboard` just did (part of gap 7's dedup).
- Help text is maintained by hand in two places: `usage()` (pc-command-center.sh:27) and readme.md — no single source of truth.
- `uptime -p` is invoked twice per header render (:509 header assembles it once per string, compact header again).

## Not found (checked, so you don't have to)

- **No TODO/FIXME/HACK markers**, no stale feature flags, no abandoned abstractions, no migrations — the codebase carries no half-finished work.
- **No secrets** committed (grep of repo and history for key/token/password patterns came back clean).
- **Panel alignment is exact**: every output line measured at precisely the target width in wide (110), compact (80), mini, micro, and tiny runs — the ANSI-aware padding layer works.

## 13. CPU sample state is lost through command substitution — Medium

Verified during v1.2 review on 2026-10-24. The layouts invoke
`cpu=$(get_cpu_usage)`. Bash runs that function in a subshell, so its writes to
`PREV_CPU_IDLE` and `PREV_CPU_TOTAL` do not reach the caller. Later frames therefore
compare against the startup baseline, rather than the immediately previous frame.
The 0.25s startup wait fixed the first-sample window in v1.1, but not this issue.

A synthetic collector returning idle=160/total=300 with previous=100/200 produces
40% while leaving caller counters at 100/200. A direct function call does update
them (covered by the v1.2 CPU math test). This distinction is not covered by the
headless layout checks.

**Resolved in v1.3:** `collect_metrics` calls CPU collection in the parent shell
and stores its value in `METRIC_CPU`. A regression renders consecutive frames
and verifies both the reported usage and advancing baseline counters.
