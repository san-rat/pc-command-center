# ROADMAP.md — Staged version specs

This document records completed stages and future work orders. Future versions are
strictly sequential; each assumes the previous stage is complete. Gap numbers
refer to **GAPS.md**, which preserves the original audit.

## Current status (2026-10-24)

- **v1.1 complete:** committed as `aff1799` on 2026-07-23.
- **v1.2 implemented:** regression tests, lint fixes, CI workflow, MIT license,
  source guard, and `--version`. Local verification is recorded in
  [WORKLOG.md](WORKLOG.md); the hosted CI run remains unverified until pushed.
- **v1.3 implemented:** parent-shell collection, shared formatters/dimensions,
  and signal-driven resizing. Local checks pass; all five deterministic fixture
  layouts match v1.2, and idle subprocesses dropped to zero in a two-second sample.
  See [WORKLOG.md](WORKLOG.md) for measurements and terminal checks.
- **Next: v1.4.** Configurability; v2.0, v2.1, and v3.0 also remain planned.

The original v1.0 baseline was `3bcedcf`.

---

## v1.1 — Correctness patch (complete)

**Goal:** Every number and name on screen is right. No new features, no restructuring — smallest possible diffs.

**Spec:**
1. Fix `sensors` temperature parsing (gap 1): extract the first numeric temperature from the matched line in `get_temperature` instead of printing `$2`. Must handle all three formats: `Package id 0:  +42.0°C`, `Core 0:  +40.0°C`, `temp1:  +42.0°C`.
2. Fix process rows for space-containing command names (gap 2): parse PID from `$1` and CPU/MEM from `$(NF-1)`/`$NF`, joining the middle fields as the name — in all three sites (`process_panel`, `compact_process_rows`, `top_process_summary`). `Isolated Web Co` must render with correct CPU/MEM columns.
3. Fix first-frame CPU sampling (gap 4): after `init_cpu_sample`, wait ~0.25s before the first render (at minimum when `--once`). A `--once` run on an idle machine must report an idle-looking CPU%, not 90–100%.
4. Fix keypress double-render (gap 10): after `r`/`+`/`-`, schedule `NEXT_DRAW` one full interval ahead so exactly one frame is painted per keypress.
5. Fix `--interval` overflow noise (gap 11): absurdly large values must produce only the clean `die` message, no raw Bash `[: integer expression expected` on stderr.
6. Sweep gap 12 trivia: declare `CPU_IDLE`/`CPU_TOTAL`/`NEXT_DRAW` in the globals header, delete the dead `ONCE=1` in `run_live`, drop the duplicate `cup 0 0` in `render_wide_dashboard`.

**Done when:** all five bug reproductions from GAPS.md no longer reproduce; the alignment check (`--once --wide | awk '{print length($0)}' | sort -u`) still prints one number; `readme.md` updated where behavior changed (`--once` timing).

## v1.2 — Safety net (implemented; hosted CI pending)

**Goal:** Lock v1.1's fixes in place and make every future version verifiable. No product behavior changes.

**Spec:**
1. Make the script sourceable without executing (`return` guard around `main "$@"`), so functions can be unit-tested.
2. Add `tests/` on bats-core covering at minimum: `pad_ansi` (pad, exact-fit, truncate-with-`~`, ANSI-colored input), `temperature_number`, `status_color` thresholds, `bar` clamping (0, 100, >100, non-numeric), the sensors-format parsing from v1.1, the space-in-comm parsing from v1.1, and `parse_args` rejection cases (`--interval 0`, `abc`, overflow, `--bogus`).
3. Add golden layout tests: run `TERM= COLUMNS=<c> LINES=<l> ./pc-command-center.sh --once` at 80×24, 50×14, 40×9, 30×5, and 110×30 `--wide`; assert exit 0 and that every output line has identical width.
4. Make the script `shellcheck`-clean (add targeted `# shellcheck disable=` with justification comments only where a warning is genuinely wrong).
5. Add GitHub Actions workflow running shellcheck + bats on push/PR.
6. Add `LICENSE` (MIT) — gap 8 — and a `--version` flag printing a semver sourced from one variable at the top of the script.
7. Record the new test/lint commands in `CLAUDE.md`.

**Done when:** CI is green on a fresh clone; deliberately re-introducing the gap-1 awk bug makes a test fail.

## v1.3 — Single-pass engine (implemented; hosted CI pending)

**Goal:** Same pixels on screen, a fraction of the work: one data-collection pass per frame, near-zero idle cost. This is the refactor that makes v1.4/v2.0 cheap. Do not attempt before v1.2 — the tests are the regression net.

**Spec:**
1. Add `collect_metrics()` in the parent shell (avoid losing CPU sample state through command substitution; gap 13), and add a consecutive-frame CPU regression: run each source exactly once per frame (`/proc/stat`, one `free`, one `df`, one `ps`, one `ip` pass, temperature) and fill `METRIC_*` globals, including pre-computed percents and the swap-zero/temp-N/A normalizations that today live in five renderers (gap 7).
2. Convert all five renderers (`system_panel`, `compact_system_rows`, mini, micro, tiny) into pure consumers of `METRIC_*` — no `get_*` calls inside renderers.
3. Extract one shared process-table formatter used by `process_panel` and `compact_process_rows` (parameterized on name width and row limit).
4. Add `read_dimensions()` replacing the four copies of the cols/lines fetch-and-validate block.
5. Cut idle-loop churn (gap 6): use `$EPOCHSECONDS` instead of `date +%s` spawns; re-read terminal size via a `WINCH` trap (fall back to per-second polling if trap proves unreliable in the target terminal).
6. Deduplicate the remaining doubles: single `free` parse for mem+swap, single `uptime -p` per frame.

**Done when:** all v1.2 tests and golden layouts pass unchanged; process count spawned per idle second (measurable via `strace -f -e trace=process -c`, or a fork counter) drops by an order of magnitude; every metric-handling change now touches exactly one function.

## v1.4 — Configurability

**Goal:** Stop hardcoding the user's choices; keep zero-config behavior identical to v1.3.

**Spec:**
1. Optional config file `~/.config/pc-command-center.conf` (simple `KEY=value`, sourced safely — parse known keys only, never blind `source`): refresh interval, color on/off, warn/crit thresholds per metric, monitored disk mount(s), preferred network interface, forced layout.
2. New flags overriding the config: `--layout compact|mini|micro|tiny|wide` (replaces the special-cased `--wide`, which stays as an alias), `--disk PATH` (default `/`).
3. Precedence: defaults < config file < CLI flags. Invalid config keys/values produce one warning line and are ignored — never a crash.
4. `usage()` and `readme.md` document every key and flag (they remain hand-synced — the rule in CLAUDE.md).

**Done when:** with no config file present, all v1.2 golden outputs are byte-identical; each config key is exercised by at least one test; `--layout mini` in a huge terminal renders the mini layout.

## v2.0 — New telemetry

**Goal:** Show the things a quarter-screen watcher actually wants next. Major version because layouts gain rows. Depends on v1.3's single-pass engine (every new metric is one `collect_metrics` addition + renderer rows).

**Spec:**
1. Network throughput: RX/TX rates from `/proc/net/dev` deltas between frames (same prev/current pattern as CPU) for the active interface; shown in compact `NET` row and wide Network panel.
2. Interval-accurate top processes (the real fix for gap 5): compute per-PID CPU% from `/proc/[pid]/stat` deltas between frames in live mode; keep `ps` lifetime values only for `--once` (labeled `avg`); exclude the dashboard's own PID.
3. Battery: charge % + charging state from `/sys/class/power_supply/BAT*` when present; row hidden on desktops.
4. Per-core CPU mini-bars in the wide layout only (from per-cpu lines of `/proc/stat`).
5. Each addition degrades to absent/`N/A` when its source is missing, matching existing philosophy; readme Requirements updated.

**Done when:** golden tests updated and passing for all tiers with and without battery present; a `dd`/`curl` transfer visibly moves the RX/TX numbers; the dashboard's own process no longer appears in its live top list.

## v2.1 — Interactivity

**Goal:** Make live mode operable, not just watchable, while keeping the key-handling model (single-char reads in the 0.1s poll loop).

**Spec:**
1. `c`/`m` toggle process sort between CPU and memory (indicator in the `TOP` header).
2. `p` pauses/resumes refresh (header shows `PAUSED`; keys still handled while paused).
3. `?` overlays a help panel listing all keys; any key dismisses and forces a full repaint.
4. `n` cycles the network interface shown when several are active.
5. Controls footer updated in every tier that has room; `usage()` and readme "Live Controls" sections updated.

**Done when:** each key is covered by a scripted-TTY test (bats + `script`/`tmux send-keys`) or, where that's impractical, a documented manual test checklist in the PR; terminal state still restores cleanly on quit from every mode including paused/help.

## v3.0 — Distribution

**Goal:** Installable and versioned like a real tool, not a script you clone. The license prerequisite was addressed in v1.2.

**Spec:**
1. `man` page (`pc-command-center.1`, can be generated from readme via pandoc — commit the generated page, note the generator).
2. `install.sh` (or a `Makefile` with `install`/`uninstall`) placing the script in `~/.local/bin/pcc` or `/usr/local/bin`, plus the man page.
3. Debian packaging (`.deb` via `dpkg-deb` or `nfpm`) built in CI on tag push; GitHub Release with changelog.
4. Maintain the `CHANGELOG.md` introduced in v1.2; add release tags from the corresponding verified commits.
5. Rename decision recorded: keep `pc-command-center.sh` as repo file but install as `pcc`.

**Done when:** on a clean Ubuntu container: `dpkg -i` the artifact → `pcc --version` works → `man pcc` renders → `pcc` runs → uninstall leaves nothing behind.
