#!/usr/bin/env bats

setup() {
    source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
    CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"
    tput_cmd() { :; }
    read_cpu_times() {
        echo cpu >> "$CALLS"
        CPU_IDLE=${TEST_IDLE:-160}
        CPU_TOTAL=${TEST_TOTAL:-300}
    }
    free() {
        echo free >> "$CALLS"
        [ "${EMPTY:-0}" -eq 1 ] && return
        printf 'Mem: 8589934592 2147483648\nSwap: %s %s\n' "${SWAP_TOTAL:-4294967296}" "${SWAP_USED:-1073741824}"
    }
    df() {
        echo df >> "$CALLS"
        [ "${EMPTY:-0}" -eq 1 ] && return
        printf 'Filesystem Size Used Avail Use%% Mounted\n/dev/root 100G 25G 75G 25%% /\n'
    }
    ps() {
        echo ps >> "$CALLS"
        [ "${EMPTY:-0}" -eq 1 ] && return
        printf '%s\n' '1234 Isolated Web Co 12.3 4.5' '2345 tmux: server 1.2 0.3'
    }
    ip() {
        echo ip >> "$CALLS"
        [ "${EMPTY:-0}" -eq 1 ] && return
        local index
        for index in 1 2 3 4 5; do
            printf '%s: eth%s inet 192.0.2.%s/24 scope global\n' "$index" "$index" "$index"
        done
        printf 'default via 192.0.2.254 dev eth1\ndefault via 192.0.2.253 dev eth2\n'
    }
    get_temperature() {
        echo temperature >> "$CALLS"
        printf '%s' "${TEST_TEMP:-+42.0°C}"
    }
    uptime() { echo uptime >> "$CALLS"; echo 'up 1 hour'; }
    hostname() { echo hostname >> "$CALLS"; echo fixture-host; }
    whoami() { echo whoami >> "$CALLS"; echo fixture-user; }
    date() { echo date >> "$CALLS"; echo '2026-10-24 12:34:56'; }
    getconf() { echo getconf >> "$CALLS"; echo 4; }
}

@test "all layouts collect each source exactly once per frame" {
    local spec source
    for spec in '80 24 0' '50 14 0' '40 9 0' '30 5 0' '110 30 1'; do
        read -r COLUMNS LINES WIDE_MODE <<< "$spec"
        : > "$CALLS"
        render_dashboard > "$BATS_TEST_TMPDIR/frame"
        for source in cpu free df ps ip temperature uptime hostname whoami date getconf; do
            [ "$(grep -cx "$source" "$CALLS")" -eq 1 ]
        done
    done
}

@test "consecutive rendered frames advance CPU counters in the parent shell" {
    COLUMNS=30 LINES=5
    PREV_CPU_IDLE=100 PREV_CPU_TOTAL=200
    render_dashboard > "$BATS_TEST_TMPDIR/frame"
    [ "$METRIC_CPU" -eq 40 ]
    [ "$PREV_CPU_IDLE" -eq 160 ]
    [ "$PREV_CPU_TOTAL" -eq 300 ]
    TEST_IDLE=180 TEST_TOTAL=400
    render_dashboard > "$BATS_TEST_TMPDIR/frame"
    [ "$METRIC_CPU" -eq 80 ]
    [ "$PREV_CPU_IDLE" -eq 180 ]
    [ "$PREV_CPU_TOTAL" -eq 400 ]
    grep -q 'CPU 80%' "$BATS_TEST_TMPDIR/frame"
}

@test "collection shares memory, disk, process and network data" {
    collect_metrics
    [ "$METRIC_MEM_USED/$METRIC_MEM_TOTAL $METRIC_MEM_PERCENT" = '2.0Gi/8.0Gi 25' ]
    [ "$METRIC_SWAP_USED/$METRIC_SWAP_TOTAL $METRIC_SWAP_PERCENT" = '1.0Gi/4.0Gi 25' ]
    [ "$METRIC_DISK_USED/$METRIC_DISK_TOTAL $METRIC_DISK_AVAILABLE $METRIC_DISK_PERCENT" = '25G/100G 75G 25' ]
    [ "$METRIC_PROCESS_COUNT" -eq 2 ]
    [ "$METRIC_INTERFACE" = 'eth1 192.0.2.1/24' ]
    [ "${#METRIC_INTERFACES[@]}" -eq 4 ]
    [ "$METRIC_GATEWAY" = '192.0.2.254 via eth1' ]
    [ "$METRIC_TEMP_SHORT $METRIC_TEMP_PERCENT" = '+42.0°C 42' ]
    [ "$(top_process_summary 10)" = 'Isolated ~ 12.3%' ]
    [ "$(format_process_rows 10 1 5 | wc -l)" -eq 1 ]
}

@test "zero swap and absent sources replace previous frame values" {
    collect_metrics
    SWAP_TOTAL=0 SWAP_USED=0 TEST_TEMP='Not available'
    collect_metrics
    [ "$METRIC_SWAP_USED/$METRIC_SWAP_TOTAL $METRIC_SWAP_PERCENT" = '0B/0B 0' ]
    [ "$METRIC_TEMP" = 'Not available' ]
    [ "$METRIC_TEMP_SHORT $METRIC_TEMP_PERCENT" = 'N/A 0' ]
    EMPTY=1
    collect_metrics
    [ "$METRIC_MEM_USED/$METRIC_MEM_TOTAL $METRIC_MEM_PERCENT" = 'N/A/N/A 0' ]
    [ "$METRIC_DISK_PERCENT" -eq 0 ]
    [ -z "$METRIC_DISK_AVAILABLE" ]
    [ "$METRIC_PROCESS_COUNT" -eq 0 ]
    [ -z "$(format_process_rows 10 4 5)" ]
    [ "$(top_process_summary 10)" = N/A ]
    [ "${#METRIC_INTERFACES[@]}" -eq 0 ]
    [ "$METRIC_INTERFACE" = 'No active IPv4' ]
    [ -z "$METRIC_GATEWAY" ]
}

@test "memory formatting retains integer GiB and small swap units" {
    free() { printf 'Mem: 17179869184 10737418240\nSwap: 524288 1024\n'; }
    collect_metrics
    [ "$METRIC_MEM_USED/$METRIC_MEM_TOTAL $METRIC_MEM_PERCENT" = '10Gi/16Gi 62' ]
    [ "$METRIC_SWAP_USED/$METRIC_SWAP_TOTAL $METRIC_SWAP_PERCENT" = '1.0Ki/512Ki 0' ]
}

@test "live rendering caches dimensions until a resize is signaled" {
    tput_cmd() { echo "$*" >> "$CALLS"; }
    LIVE_MODE=1 COLUMNS=30 LINES=5
    render_dashboard > /dev/null
    [ "$TERM_COLS $TERM_LINES $RESIZE_PENDING" = '30 5 0' ]
    COLUMNS=40 LINES=9
    render_dashboard > /dev/null
    [ "$TERM_COLS $TERM_LINES" = '30 5' ]
    RESIZE_PENDING=1
    render_dashboard > /dev/null
    [ "$TERM_COLS $TERM_LINES $RESIZE_PENDING" = '40 9 0' ]
    [ "$(grep -cx cols "$CALLS")" -eq 2 ]
    [ "$(grep -cx lines "$CALLS")" -eq 2 ]
}

@test "invalid terminal dimensions fall back to usable defaults" {
    COLUMNS=invalid LINES=0
    read_dimensions
    [ "$TERM_COLS $TERM_LINES" = '80 24' ]
    tput_cmd() { printf '%s' 99999999999999999999; }
    COLUMNS=50 LINES=14
    read_dimensions
    [ "$TERM_COLS $TERM_LINES" = '50 14' ]
}

@test "a resize during dimension queries remains pending" {
    trap 'RESIZE_PENDING=1' WINCH
    # Signal the parent while its dimension query is running in a subshell.
    local parent=$BASHPID
    tput_cmd() { kill -WINCH "$parent"; }
    read_dimensions
    [ "$RESIZE_PENDING" -eq 1 ]
    trap - WINCH
}

@test "refresh keys draw once and schedule the next refresh without date" {
    render_dashboard() { echo draw >> "$CALLS"; }
    date() { echo unexpected-date >> "$CALLS"; return 1; }
    local key before
    for key in r + -; do
        before=${EPOCHSECONDS:-$SECONDS}
        handle_key "$key"
        [ "$NEXT_DRAW" -ge "$((before + REFRESH_INTERVAL))" ]
    done
    [ "$(cat "$CALLS")" = $'draw\ndraw\ndraw' ]
}
