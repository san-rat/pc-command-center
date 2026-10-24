#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    REFRESH_INTERVAL=10
    ALERT_TRIGGER_SECONDS=10 ALERT_RECOVERY_SECONDS=5
}
observe() {
    SAMPLE_TIME_MS=$(( $1 * 1000 ))
    alert_observe cpu "$2" "${3:-valid}" 60 85 5 CPU
}

@test "short spikes do not warn and a sustained threshold warns only once" {
    observe 1 70; observe 5 30; observe 10 70
    [ "$EVENT_COUNT" -eq 0 ]
    observe 20 70
    [ "${ALERT_ACTIVE[cpu]}" -eq 1 ]
    [ "$EVENT_COUNT" -eq 1 ]
    observe 25 70
    [ "$EVENT_COUNT" -eq 1 ]
}

@test "warnings escalate downgrade and clear with separate durations" {
    observe 1 60; observe 11 60
    [ "${ALERT_ACTIVE[cpu]}" -eq 1 ]
    observe 12 85; observe 22 85
    [ "${ALERT_ACTIVE[cpu]}" -eq 2 ]
    observe 23 79; observe 28 79
    [ "${ALERT_ACTIVE[cpu]}" -eq 1 ]
    observe 29 55; observe 34 55
    [ "${ALERT_ACTIVE[cpu]}" -eq 0 ]
    [ "$EVENT_COUNT" -eq 4 ]
}

@test "hysteresis avoids flicker and missing data never reports recovery" {
    observe 1 70; observe 11 70
    observe 12 58; observe 18 58
    [ "${ALERT_ACTIVE[cpu]}" -eq 1 ]
    observe 19 0 unavailable
    [ "${ALERT_ACTIVE[cpu]} ${ALERT_UNKNOWN[cpu]}" = '1 1' ]
    observe 20 20; observe 24 20
    [ "${ALERT_ACTIVE[cpu]}" -eq 1 ]
    observe 25 20
    [ "${ALERT_ACTIVE[cpu]}" -eq 0 ]
}

@test "long gaps reset pending duration and low thresholds can recover at zero" {
    observe 1 70; observe 100 70
    [ "${ALERT_ACTIVE[cpu]:-0}" -eq 0 ]
    SAMPLE_TIME_MS=1000; alert_observe ram 2 valid 1 5 5 RAM
    SAMPLE_TIME_MS=11000; alert_observe ram 2 valid 1 5 5 RAM
    [ "${ALERT_ACTIVE[ram]}" -eq 1 ]
    SAMPLE_TIME_MS=12000; alert_observe ram 0 valid 1 5 5 RAM
    SAMPLE_TIME_MS=17000; alert_observe ram 0 valid 1 5 5 RAM
    [ "${ALERT_ACTIVE[ram]}" -eq 0 ]
}

@test "event buffer is bounded and warnings can be disabled independently" {
    EVENT_CAPACITY=10
    local i
    for ((i=0;i<25;i++)); do append_event "event $i"; done
    [ "$EVENT_COUNT $EVENT_HEAD ${#EVENTS[@]}" = '10 5 10' ]
    [ "${EVENTS[4]}" = ' event 24' ]
    WARNINGS_ENABLED=0
    sample_set cpu 100; evaluate_alerts
    [ "${#ALERT_ACTIVE[@]}" -eq 0 ]
}

@test "an unavailable inactive metric returning to normal does not emit a false recovery" {
    observe 1 0 unavailable
    observe 2 0; observe 12 0
    [ "$EVENT_COUNT" -eq 0 ]
}
