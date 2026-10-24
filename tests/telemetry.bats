#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    CPU_COUNT=4
    LIVE_MODE=1
    CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"
}

@test "per-core CPU percentages use each core's counter deltas" {
    read_cpu_times() {
        CPU_IDLE=160 CPU_TOTAL=300
        CPU_CORE_TOTALS=(200 150)
        CPU_CORE_IDLES=(100 70)
    }
    PREV_CPU_IDLE=100 PREV_CPU_TOTAL=200
    PREV_CORE_TOTALS=(100 100)
    PREV_CORE_IDLES=(50 50)

    get_cpu_usage >/dev/null

    [ "${METRIC_CORE_CPUS[*]}" = '50 60' ]
    [ "${PREV_CORE_TOTALS[*]}" = '200 150' ]
}

@test "network rates use selected interface byte counter deltas" {
    NETWORK_INTERFACE=eth0
    TEST_RX=1000 TEST_TX=3000
    read_network_counters() {
        echo "$1 $TEST_RX $TEST_TX" >> "$CALLS"
        printf '%s %s\n' "$TEST_RX" "$TEST_TX"
    }
    SAMPLE_TIME_MS=2000
    collect_network_metrics
    [ "$METRIC_NET_INTERFACE $METRIC_NET_RX_RATE $METRIC_NET_TX_RATE" = 'eth0 N/A N/A' ]

    TEST_RX=3048 TEST_TX=4024
    PREV_NET_INTERFACE=eth0 PREV_NET_RX=1000 PREV_NET_TX=3000
    PREV_NET_TIME=2000
    SAMPLE_TIME_MS=4000
    collect_network_metrics

    [ "$METRIC_NET_RX_RATE $METRIC_NET_TX_RATE" = '1.0KiB/s 512B/s' ]
    [ "$(wc -l < "$CALLS")" -eq 2 ]
}

@test "live process ranking uses CPU deltas, keeps spaced names, and excludes self" {
    CPU_DIFF_TOTAL=100
    PREV_PROC_TICKS=([1234]=100 [2345]=200)
    PREV_PROC_START=([1234]=1 [2345]=2)
    read_process_ticks() {
        echo read >> "$CALLS"
        printf '1234 150 1\n2345 210 2\n'
    }
    ps() {
        echo ps >> "$CALLS"
        printf '%s\n' '1234 user S 1 100 1 1 12.3 4.5 Isolated Web Co' '2345 user S 1 100 1 1 1.2 0.3 worker' "$$ user S 1 100 1 1 99.0 1.0 self"
    }

    collect_live_processes

    [ "$METRIC_PROCESS_CPU_MODE" = now ]
    [ "$(head -n 1 <<< "$METRIC_PROCESSES")" = '1234 Isolated Web Co 200.0 4.5' ]
    [ "$(format_process_rows 24 2 6 | head -n 1 | awk '{print $1, $NF}')" = '1234 4.5%' ]
    ! grep -q "^$$ " <<< "$METRIC_PROCESSES"
    [ "$(cat "$CALLS")" = $'read\nps' ]
}

@test "battery and per-core bars appear in wide system data when available" {
    METRIC_CORE_CPUS=(25 100)
    METRIC_BATTERY='87% charging'
    run system_panel 50
    [ "$status" -eq 0 ]
    [[ "$output" == *'Core 0'*'25%'* ]]
    [[ "$output" == *'Core 1'*'100%'* ]]
    [[ "$output" == *'Battery   87% charging'* ]]
}

@test "one-shot process display identifies lifetime averages" {
    METRIC_PROCESS_CPU_MODE=avg
    METRIC_PROCESSES='1234 worker 12.3 4.5'
    run process_panel 80 1
    [ "$status" -eq 0 ]
    [[ "$output" == *'CPU* AVG'* ]]
}
