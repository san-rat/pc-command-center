#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    SCRIPT="$BATS_TEST_DIRNAME/../pc-command-center.sh"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    source "$SCRIPT"
}

@test "sourcing defines functions without running main or installing traps" {
    # A child shell can inherit ignored signals from the test runner.
    run bash -c '
        trap "" INT
        before=$(trap -p)
        source "$1" || exit
        declare -F render_dashboard >/dev/null || exit
        [ "$(trap -p)" = "$before" ]
    ' _ "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "pad_ansi pads, preserves exact fits, and truncates with a marker" {
    [ "$(pad_ansi abc 5)" = 'abc  ' ]
    [ "$(pad_ansi abc 3)" = abc ]
    [ "$(pad_ansi abcdef 4)" = abc~ ]
    [ "$(pad_ansi abc 1)" = a ]
    [ -z "$(pad_ansi abc 0)" ]
    [ -z "$(pad_ansi abc -1)" ]
}

@test "pad_ansi measures colored text by visible width" {
    local colored=$'\e[31mabc\e[0m'
    [ "$(pad_ansi "$colored" 5)" = "$colored  " ]
    [ "$(visible_length "$(pad_ansi "$colored" 5)")" -eq 5 ]
    [ "$(pad_ansi "$colored" 2)" = a~ ]
}

@test "temperature_number handles both sources and absent readings" {
    [ "$(temperature_number '+42.9°C')" = 42 ]
    [ "$(temperature_number '27C')" = 27 ]
    [ "$(temperature_number 'Not available')" = 0 ]
    [ "$(temperature_number '')" = 0 ]
}

@test "status_color changes exactly at warning and critical thresholds" {
    GREEN=healthy YELLOW=warning RED=critical DIM=unknown
    [ "$(status_color 59 60 85)" = healthy ]
    [ "$(status_color 60 60 85)" = warning ]
    [ "$(status_color 84 60 85)" = warning ]
    [ "$(status_color 85 60 85)" = critical ]
    [ "$(status_color invalid 60 85)" = unknown ]
}

@test "bar clamps invalid and out-of-range values" {
    [ "$(bar 0 5 '')" = '[-----]' ]
    [ "$(bar 100 5 '')" = '[#####]' ]
    [ "$(bar 150 5 '')" = '[#####]' ]
    [ "$(bar invalid 5 '')" = '[-----]' ]
    [ "$(bar -1 5 '')" = '[-----]' ]
    [ "$(bar 50 0 '')" = '[]' ]
}

@test "CPU usage uses counter deltas and handles no elapsed ticks" {
    read_cpu_times() { CPU_IDLE=160; CPU_TOTAL=300; }
    PREV_CPU_IDLE=100 PREV_CPU_TOTAL=200
    get_cpu_usage > "$BATS_TEST_TMPDIR/cpu"
    [ "$(cat "$BATS_TEST_TMPDIR/cpu")" = 40 ]
    [ "$PREV_CPU_IDLE" -eq 160 ]
    [ "$PREV_CPU_TOTAL" -eq 300 ]
    [ "$(get_cpu_usage)" = 0 ]
}

@test "sensors parses Package, Core, and temp1 formats" {
    sensors() { printf '%s\n' "$SAMPLE"; }
    SAMPLE='Package id 0:  +42.0°C'
    [ "$(get_temperature)" = '+42.0°C' ]
    SAMPLE='Core 0:  +40.0°C'
    [ "$(get_temperature)" = '+40.0°C' ]
    SAMPLE='temp1:  +42.0°C'
    [ "$(get_temperature)" = '+42.0°C' ]
}

@test "all three process formatters preserve names with spaces and numeric columns" {
    ps() {
        case "$*" in
            *'pid=,comm=,%cpu=,%mem='*)
                printf '%s\n' '1234 Isolated Web Co 12.3 4.5' '2345 tmux: server 1.2 0.3' ;;
            *'comm=,%cpu='*) printf '%s\n' 'Isolated Web Co 12.3' ;;
            *) return 1 ;;
        esac
    }
    METRIC_PROCESSES=$(ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu)
    run process_panel 80 2
    [ "$status" -eq 0 ]
    [[ "$output" =~ Isolated\ Web\ Co[[:space:]]+12\.3%[[:space:]]+4\.5% ]]
    [[ "$output" =~ tmux:\ server[[:space:]]+1\.2%[[:space:]]+0\.3% ]]
    run compact_process_rows 80 2
    [ "$status" -eq 0 ]
    [[ "$output" =~ Isolated\ Web\ Co[[:space:]]+12\.3%[[:space:]]+4\.5% ]]
    [ "$(top_process_summary 30)" = 'Isolated Web Co 12.3%' ]
}

@test "argument errors are clean for invalid, missing, overflow, and unknown values" {
    local value
    for value in 0 abc -1 1.5 1000000 99999999999999999999; do
        run bash "$SCRIPT" --interval "$value"
        [ "$status" -eq 1 ]
        [[ "$output" == Error:* ]]
        [ "${#lines[@]}" -eq 2 ]
        [[ "$output" != *'integer expression expected'* ]]
    done
    run bash "$SCRIPT" --interval
    [ "$status" -eq 1 ]
    [[ "$output" == *'requires a value'* ]]
    run bash "$SCRIPT" --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *'unknown option'* ]]
}

@test "valid arguments set options including interval bounds" {
    parse_args --interval 1 --no-color --once --wide
    [ "$REFRESH_INTERVAL" -eq 1 ]
    [ "$ENABLE_COLOR" -eq 0 ]
    [ "$ONCE" -eq 1 ]
    [ "$LAYOUT" = wide ]
    parse_args --interval 999999
    [ "$REFRESH_INTERVAL" -eq 999999 ]
}

@test "help and version exit without rendering the dashboard" {
    run bash "$SCRIPT" --version
    [ "$status" -eq 0 ]
    [ "$output" = "PC Command Center $VERSION" ]
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *'--version'* ]]
    [[ "$output" == *'Live controls:'* ]]
}

@test "layout routing respects both dimension boundaries" {
    tput_cmd() { :; }
    collect_metrics() { :; }
    render_compact_dashboard() { echo compact; }
    render_mini_dashboard() { echo mini; }
    render_micro_dashboard() { echo micro; }
    render_tiny_fallback() { echo tiny; }
    render_wide_dashboard() { echo wide; }
    local spec cols rows expected
    for spec in '60 20 compact' '59 20 mini' '60 19 mini' '45 12 mini' '44 12 micro' '45 11 micro' '36 8 micro' '35 8 tiny' '36 7 tiny'; do
        read -r cols rows expected <<< "$spec"
        COLUMNS=$cols LINES=$rows
        [ "$(render_dashboard)" = "$expected" ]
    done
    LAYOUT=wide
    [ "$(render_dashboard)" = wide ]
}

# Live telemetry changes on every run; assert stable layout properties rather
# than snapshotting hostnames, timestamps, or usage numbers.
assert_layout() {
    local cols="$1" rows="$2" marker="$3"
    shift 3
    run env TERM= COLUMNS="$cols" LINES="$rows" bash "$SCRIPT" --once --no-color "$@"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"$marker"* ]]
    printf '%s\n' "$output" | awk -v width="$cols" 'length($0) != width {exit 1}'
}

@test "compact snapshot has consistent 80-column lines" { assert_layout 80 24 SYS; }
@test "mini snapshot has consistent 50-column lines" { assert_layout 50 14 'PCC MINI'; }
@test "micro snapshot has consistent 40-column lines" { assert_layout 40 9 'PCC MICRO'; }
@test "tiny snapshot has consistent 30-column lines" { assert_layout 30 5 'PCC'; }
@test "wide snapshot has consistent 110-column lines" { assert_layout 110 30 'Top Processes' --wide; }
