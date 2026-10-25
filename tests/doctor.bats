#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    SCRIPT="$BATS_TEST_DIRNAME/../pc-command-center.sh"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    mkdir -p "$XDG_CONFIG_HOME"
}

@test "doctor is a readable one-shot report without sampling or terminal setup" {
    collect_sample() { echo unexpected-sample; return 1; }
    setup_terminal() { echo unexpected-terminal; return 1; }
    init_cpu_sample() { echo unexpected-baseline; return 1; }
    run main --doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *'diagnostics'*'Dependencies'*'Configuration'*'Network'*'Optional hardware'* ]]
    [[ "$output" != *'unexpected-'* ]]
    [[ "$output" != *$'\e['* ]]
    [ "$SAMPLE_SEQUENCE $HISTORY_COUNT $EVENT_COUNT" = '0 0 0' ]
}

@test "doctor reports a missing required tool with a package suggestion and failure status" {
    command() {
        if [ "$1" = -v ] && [ "$2" = ip ]; then return 1; fi
        builtin command "$@"
    }
    run run_doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *'FAIL'*'ip'*'install iproute2'* ]]
    [[ "$output" == *'Required dependencies missing: 1.'* ]]
}

@test "doctor explains missing selected device and disabled pressure as optional limitations" {
    BLOCK_DEVICE=pcc_nonexistent_device PRESSURE_ENABLED=0
    run run_doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *'pcc_nonexistent_device absent/unreadable'* ]]
    [[ "$output" == *'disabled by PRESSURE_ENABLED=0'* ]]
}

@test "doctor applies profile and CLI options and reports ignored config entries" {
    mkdir -p "$XDG_CONFIG_HOME/pc-command-center/profiles"
    printf 'REFRESH_INTERVAL=3\nUNKNOWN_KEY=1\n' > "$XDG_CONFIG_HOME/pc-command-center/profiles/daily.conf"
    run bash "$SCRIPT" --doctor --interval 7 --profile daily
    [ "$status" -eq 0 ]
    [[ "$output" == *'Profile'*'daily'* ]]
    [[ "$output" == *'1 config entries/pairs ignored'* ]]
    [[ "$output" == *'refresh=7s'* ]]
}

@test "doctor rejects recording and structured output without creating a file" {
    run bash "$SCRIPT" --doctor --record "$BATS_TEST_TMPDIR/no.csv"
    [ "$status" -eq 1 ]
    [ ! -e "$BATS_TEST_TMPDIR/no.csv" ]
    run bash "$SCRIPT" --doctor --format json
    [ "$status" -eq 1 ]
}

@test "doctor probes enforce a timeout and do not execute configuration tools" {
    timeout() { printf '%s\n' "$*"; }
    run doctor_probe free -b
    [ "$status" -eq 0 ]
    [ "$output" = '-k 1 2 free -b' ]
}

@test "doctor checks IPv4 and gateway for the configured interface rather than another link" {
    NETWORK_INTERFACE=lo
    local calls="$BATS_TEST_TMPDIR/probes"
    doctor_probe() {
        printf '%s\n' "$*" >> "$calls"
        if [ "$1" = ip ] && [[ "$*" != *'dev lo'* ]]; then echo other-interface; fi
        return 0
    }
    run run_doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *'no active global IPv4 address on lo'* ]]
    [[ "$output" == *'no default IPv4 route on lo'* ]]
    grep -qx 'ip -o -4 address show dev lo up scope global' "$calls"
    grep -qx 'ip -4 route show default dev lo' "$calls"
}

@test "doctor does not treat a sensor label without a temperature as a usable reading" {
    sensors() { :; }
    doctor_probe() {
        if [ "$1" = sensors ]; then echo 'Core 0: unavailable'; fi
        return 0
    }
    run run_doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *'no usable supported reading'* ]]
    [[ "$output" != *'sensors responds with a usable CPU temperature'* ]]
}
