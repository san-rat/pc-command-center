# Responsiveness measurements — 4.1.0

Measured on 2026-10-25 against the local 4.0.0 executable from commit
`458e85f402d2a2bc1c9150a4afa4b6def0c6fa39` and the 4.1.0 candidate on the same
Linux host. Seven observations per operation, 80 columns by 24 rows. Timings are
milliseconds. These are observations, not guaranteed latency budgets.

| Operation | 4.0 median | 4.1 median | 4.0 maximum | 4.1 maximum |
|---|---:|---:|---:|---:|
| Collection | 288.08 | 296.58 | 306.13 | 314.00 |
| Cached overview repaint | 163.10 | 65.99 | 172.61 | 68.89 |
| Cached Processes-view handler | 129.40 | 10.08 | 135.18 | 11.44 |
| PTY key to completed frame | 75.98 | 17.91 | 140.32 | 60.92 |

## Method

Run `python3 tests/latency.py --script /path/to/baseline.sh`, then
`python3 tests/latency.py`. The optional `--samples` setting accepts 1–100.
The harness uses only Python's standard library and Bash; it is development tooling.

The function driver sources the executable, primes CPU sampling, collects an
initial sample, and measures commands through stdin/stdout acknowledgments.
Collection invokes `collect_metrics` with real host data and updates CPU/process
baselines. Rendering reuses cached metrics without collecting. The handler
measurement invokes `handle_key 2` repeatedly on that cache. Driver acknowledgments
and pipe overhead are included. Startup and its initial sampling delay are excluded.

The terminal measurement launches the normal dashboard in a Linux PTY with xterm
capabilities, color disabled, an isolated empty config directory, and a very long
refresh interval. It alternates Processes, Network, Overview, Storage, and Pressure
view keys. Time runs from writing a key until the frame's clear-to-end capability
is received. Scheduled sampling cannot interfere in this measurement. It does not
measure keys arriving during collection. The separate functional PTY tests verify
pause/help, sampling/recording counts, resize and terminal restoration.

Raw summaries are in [performance-4.1.json](performance-4.1.json).

## Interpretation and limits

Cached repaint and navigation are faster in this paired run. SGR removal no longer
launches sed, width calculations reuse a Bash result, and fitted lines avoid an
extra command substitution. Pressure reads also avoid cat subprocesses.
Collection stayed around 290–300 ms; no collection-speed improvement is claimed.
Initial exploratory measurements varied under host load, so use the documented
paired run for comparison rather than mixing numbers from different probes.

Sampling remains synchronous, preserves one publication per completed sample, and
keeps rate baselines in the parent shell. Process count, selected filesystem
latency, CPU scheduling, terminal speed and background activity affect timings.
Filesystem probes can still take their two-second timeout plus termination grace;
keys arriving during those probes wait. This change does not introduce a background
collector or claim a hard maximum input latency. There are no timing assertions in
CI: semantic regression tests and PTY checks guard correctness instead.
