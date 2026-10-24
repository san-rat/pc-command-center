#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"
    LIVE_MODE=0
    collect_sample() { :; }
    render_dashboard() { echo dashboard >> "$CALLS"; }
    render_help_overlay() { echo help >> "$CALLS"; }
}

@test "c and m select CPU and memory process sorting" {
    handle_key m
    [ "$PROCESS_SORT" = mem ]
    handle_key c
    [ "$PROCESS_SORT" = cpu ]
    [ "$(cat "$CALLS")" = $'dashboard\ndashboard' ]
}

@test "live process list follows the selected memory sort" {
    PROCESS_SORT=mem
    CPU_COUNT=4
    CPU_DIFF_TOTAL=100
    PREV_PROC_TICKS=([1234]=100 [2345]=100)
    PREV_PROC_START=([1234]=1 [2345]=2)
    LIVE_MODE=1
    read_process_ticks() { printf '1234 150 1\n2345 110 2\n'; }
    ps() { printf '%s\n' '1234 user S 1 100 1 1 90.0 1.0 busy' '2345 user S 1 100 1 1 1.0 9.0 cache'; }

    collect_live_processes

    [ "$(head -n 1 <<< "$METRIC_PROCESSES")" = '2345 cache 40.0 9.0' ]
}

@test "p toggles pause and resume while keeping key refreshes available" {
    handle_key p
    [ "$PAUSED" -eq 1 ]
    [ "$NEXT_DRAW" -eq 0 ]
    handle_key r
    [ "$PAUSED" -eq 1 ]
    handle_key p
    [ "$PAUSED" -eq 0 ]
    [ "$NEXT_DRAW" -gt 0 ]
    [ "$(wc -l < "$CALLS")" -eq 3 ]
}

@test "help overlay dismisses on any key and forces a dashboard repaint" {
    handle_key '?'
    [ "$HELP_VISIBLE" -eq 1 ]
    [ "$(cat "$CALLS")" = help ]
    handle_key q
    [ "$HELP_VISIBLE" -eq 0 ]
    [ "$RESIZE_PENDING" -eq 1 ]
    [ "$(cat "$CALLS")" = $'help\ndashboard' ]
}

@test "network key cycles through available interfaces and skips when only one exists" {
    METRIC_ALL_INTERFACES=('eth0 192.0.2.1/24' 'wlan0 192.0.2.2/24')
    NETWORK_INTERFACE=eth0
    handle_key n
    [ "$NETWORK_INTERFACE" = wlan0 ]
    handle_key n
    [ "$NETWORK_INTERFACE" = eth0 ]
    [ "$(wc -l < "$CALLS")" -eq 2 ]

    METRIC_ALL_INTERFACES=('eth0 192.0.2.1/24')
    handle_key n
    [ "$NETWORK_INTERFACE" = eth0 ]
    [ "$(wc -l < "$CALLS")" -eq 2 ]
}

@test "help overlay lists controls and adapts to the terminal width" {
    local help_output
    source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
    TERM_COLS=45 TERM_LINES=5
    help_output=$(render_help_overlay)
    [ "$(printf '%s\n' "$help_output" | wc -l)" -eq 5 ]
    printf '%s\n' "$help_output" | awk 'length($0) != 45 { exit 1 }'
    [[ "$help_output" == *'c CPU | m memory'* ]]
    [[ "$help_output" == *'p pause/resume'* ]]
    [[ "$help_output" == *'n network interface'* ]]
}

@test "help overlay compresses for very short terminals" {
    local help_output
    source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
    TERM_COLS=30 TERM_LINES=3
    help_output=$(render_help_overlay)
    [ "$(printf '%s\n' "$help_output" | wc -l)" -eq 3 ]
    printf '%s\n' "$help_output" | awk 'length($0) != 30 { exit 1 }'
    [[ "$help_output" == *'q/r +/- c/m p ? n'* ]]
}
