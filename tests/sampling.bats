#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    LIVE_MODE=1
    CLOCK_FIXTURE=1000
    read_sample_clock() { CLOCK_MS=$CLOCK_FIXTURE; }
    collect_metrics() {
        COLLECTIONS=$((${COLLECTIONS:-0} + 1))
        sample_set cpu 25; sample_set ram 50; sample_set rx 100; sample_set tx 200
        METRIC_TIME=2026-10-24T12:00:00Z
    }
    record_sample() { RECORDS=$((${RECORDS:-0} + 1)); }
    render_dashboard() { REPAINTS=$((${REPAINTS:-0} + 1)); }
}

@test "one sample is published once and same-timestamp requests are coalesced" {
    collect_sample
    ! collect_sample
    [ "$COLLECTIONS $SAMPLE_SEQUENCE $HISTORY_COUNT $RECORDS" = '1 1 1 1' ]
    CLOCK_FIXTURE=2000
    collect_sample
    [ "$COLLECTIONS $SAMPLE_SEQUENCE $HISTORY_COUNT $RECORDS $SAMPLE_INTERVAL_MS" = '2 2 2 2 1000' ]
}

@test "sort view speed and selection keys repaint without collecting" {
    collect_sample
    local key
    for key in c m 1 2 3 4 5 + - j k; do handle_key "$key"; done
    [ "$COLLECTIONS $SAMPLE_SEQUENCE $HISTORY_COUNT $RECORDS" = '1 1 1 1' ]
    [ "$REPAINTS" -eq 11 ]
}

@test "pause permits explicit refresh and resume re-primes rates" {
    collect_sample
    handle_key p
    [ "$PAUSED $COLLECTIONS" = '1 1' ]
    CLOCK_FIXTURE=2000
    handle_key r
    [ "$PAUSED $COLLECTIONS $SAMPLE_SEQUENCE" = '1 2 2' ]
    handle_key p
    [ "$PAUSED" -eq 0 ]
}

@test "long sampling gaps mark history and invalidate the interval CPU sample" {
    collect_sample
    CLOCK_FIXTURE=50000
    collect_sample
    [ "${HISTORY_GAPS[1]}" = 1 ]
    [ "${SAMPLE_STATE[cpu]}" = warming ]
    [ "$METRIC_CPU" = N/A ]
    [ "$(history_graph cpu 10)" = ':|' ]
}

@test "failed clock does not publish a fake sample" {
    collect_sample
    read_sample_clock() { return 1; }
    ! collect_sample
    [ "$SAMPLE_SEQUENCE $RECORDS $BASELINE_RESET" = '1 1 1' ]
}

@test "real render does not call the collector" {
    source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
    tput_cmd() { :; }
    collect_metrics() { return 99; }
    COLUMNS=40 LINES=9
    run render_dashboard
    [ "$status" -eq 0 ]
    [[ "$output" == *'PCC MICRO'* ]]
    [ "$SAMPLE_SEQUENCE" -eq 0 ]
}

@test "CPU rollback and missing counters have explicit nonvalid states" {
    source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
    PREV_CPU_TOTAL=300 PREV_CPU_IDLE=100
    read_cpu_times() { CPU_TOTAL=200 CPU_IDLE=50; }
    get_cpu_usage > /dev/null
    [ "$CPU_SAMPLE_STATE" = warming ]
    read_cpu_times() { CPU_TOTAL=0 CPU_IDLE=0; }
    get_cpu_usage > /dev/null
    [ "$CPU_SAMPLE_STATE" = unavailable ]
}
