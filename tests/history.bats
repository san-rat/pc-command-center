#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
}

@test "zero missing gap and disabled history have distinct behavior" {
    sample_set cpu 0; append_history
    sample_set cpu '' unavailable; append_history
    SAMPLE_GAP=1; sample_set cpu 100; append_history
    [ "$(history_graph cpu 10)" = '.?|' ]
    HISTORY_ENABLED=0; append_history
    [ "$HISTORY_COUNT" -eq 3 ]
}

@test "interface switch invalidates only prior network points" {
    METRIC_NET_INTERFACE=eth0
    sample_set cpu 100; sample_set rx 100; sample_set tx 10; append_history
    METRIC_NET_INTERFACE=wlan0
    sample_set cpu 50; sample_set rx 0; sample_set tx 0; append_history
    [ "$(history_graph rx 10 100)" = '?.' ]
    [ "$(history_graph cpu 10)" = '@=' ]
}

@test "history labels actual span and shares network peak" {
    SAMPLE_TIME_MS=1000; sample_set rx 2000; sample_set tx 1; append_history
    SAMPLE_TIME_MS=11000; sample_set rx 0; sample_set tx 0; append_history
    run history_rows 80
    [[ "$output" == *'2 samples / 10s'* ]]
    [[ "$output" == *'Network peak: 1.9KiB/s'* ]]
}

@test "history ring wraps without growing and preserves chronological order" {
    HISTORY_SAMPLES=10
    local i
    for ((i=0;i<25;i++)); do
        SAMPLE_TIME_MS=$((i*1000)); sample_set cpu "$((i*4))"; append_history
    done
    [ "$HISTORY_COUNT $HISTORY_HEAD ${#HISTORY_TIMES[@]}" = '10 5 10' ]
    [ "$(history_graph cpu 4)" = '##%%' ]
    [ "${#HISTORY_VALUES[@]}" -eq 40 ]
}
