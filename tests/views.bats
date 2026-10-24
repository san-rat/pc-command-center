#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    PROC_NAME=([10:1]='Browser [tab]' [20:2]=worker [30:3]=cache)
    PROC_CPU=([10:1]=5.0 [20:2]=5.0 [30:3]=0.0)
    PROC_MEM=([10:1]=1.0 [20:2]=2.0 [30:3]=9.0)
    sort_processes
    tput_cmd() { :; }
}

@test "sort has stable PID tie-breaker and filtering is literal case-insensitive" {
    [ "${PROCESS_IDS[*]}" = '10:1 20:2 30:3' ]
    PROCESS_FILTER='[TAB]'; filter_processes
    [ "${FILTERED_IDS[*]}" = '10:1' ]
    PROCESS_FILTER='*'; filter_processes
    [ "${#FILTERED_IDS[@]}" -eq 0 ]
    PROCESS_FILTER=''; PROCESS_SORT=mem; sort_processes
    [ "${PROCESS_IDS[*]}" = '30:3 20:2 10:1' ]
}

@test "selection survives sorting and does not silently transfer after exit" {
    SELECTED_PROCESS=20:2
    PROCESS_SORT=mem; sort_processes
    [ "$SELECTED_PROCESS" = 20:2 ]
    unset 'PROC_NAME[20:2]'
    sort_processes
    [ "$SELECTED_PROCESS" = 20:2 ]
    collect_process_detail
    [ "$DETAIL_STATUS" = 'exited or unavailable' ]
    move_selection 1
    [ "$SELECTED_PROCESS" = 30:3 ]
}

@test "PID reuse resets CPU baseline and invalidates old identity" {
    LIVE_MODE=1 CPU_DIFF_TOTAL=100 CPU_COUNT=4
    PREV_PROC_TICKS=([1234]=100); PREV_PROC_START=([1234]=1)
    read_process_ticks() { echo '1234 500 2'; }
    ps() { echo '1234 user S 1 100 1 1 99.0 1.0 reused'; }
    SELECTED_PROCESS=1234:1
    collect_live_processes
    [ "${PROC_CPU[1234:2]}" = N/A ]
    [ "$DETAIL_STATUS" = 'exited or unavailable' ]
}

@test "filter input consumes q and Enter applies while Escape cancels" {
    render_dashboard() { :; }
    VIEW=processes
    handle_key /
    handle_key q
    [ "$FILTER_INPUT $FILTER_EDITING" = 'q 1' ]
    handle_key ''
    [ "$PROCESS_FILTER $FILTER_EDITING" = 'q 0' ]
    handle_key /
    handle_key x
    handle_key $'\e'
    [ "$PROCESS_FILTER" = q ]
}

@test "focused views fit small and large terminals and contain no collection" {
    local view spec
    collect_metrics() { return 99; }
    for view in processes storage network pressure; do
        for spec in '80 24' '50 14' '40 9' '30 5' '1 1'; do
            read -r COLUMNS LINES <<< "$spec"
            VIEW=$view
            run render_dashboard
            [ "$status" -eq 0 ]
            [ "${#lines[@]}" -le "$LINES" ]
            printf '%s\n' "$output" | awk -v width="$COLUMNS" 'length($0)!=width {exit 1}'
        done
    done
}

@test "control characters in display text cannot inject terminal escapes" {
    [ "$(safe_display $'ok\e[2J\n\tbad')" = 'ok?[2J??bad' ]
}
