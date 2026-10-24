#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    SCRIPT="$BATS_TEST_DIRNAME/../pc-command-center.sh"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    mkdir -p "$XDG_CONFIG_HOME"
    CONFIG="$XDG_CONFIG_HOME/pc-command-center.conf"
    source "$SCRIPT"
}

@test "absent config preserves defaults" {
    read_config
    [ "$REFRESH_INTERVAL|$ENABLE_COLOR|$LAYOUT|$DISK_PATH|$NETWORK_INTERFACE" = '5|1|auto|/|' ]
    [ "$CPU_WARN/$CPU_CRIT $RAM_WARN/$RAM_CRIT $DISK_WARN/$DISK_CRIT" = '60/85 75/90 75/90' ]
    [ "$TEMP_WARN/$TEMP_CRIT $LOAD_WARN/$LOAD_CRIT $SWAP_WARN/$SWAP_CRIT" = '70/85 70/100 50/80' ]
}

@test "every supported config key applies and threshold order is independent" {
    cat > "$CONFIG" <<'CONFIG'
REFRESH_INTERVAL=007
ENABLE_COLOR=0
DISK_PATH=/tmp
NETWORK_INTERFACE=lo
LAYOUT=mini
CPU_WARN=90
CPU_CRIT=95
RAM_WARN=70
RAM_CRIT=80
DISK_WARN=65
DISK_CRIT=85
TEMP_WARN=80
TEMP_CRIT=95
LOAD_WARN=110
LOAD_CRIT=150
SWAP_WARN=40
SWAP_CRIT=60
CONFIG
    read_config
    [ "$REFRESH_INTERVAL|$ENABLE_COLOR|$DISK_PATH|$NETWORK_INTERFACE|$LAYOUT" = '7|0|/tmp|lo|mini' ]
    [ "$CPU_WARN/$CPU_CRIT $RAM_WARN/$RAM_CRIT $DISK_WARN/$DISK_CRIT" = '90/95 70/80 65/85' ]
    [ "$TEMP_WARN/$TEMP_CRIT $LOAD_WARN/$LOAD_CRIT $SWAP_WARN/$SWAP_CRIT" = '80/95 110/150 40/60' ]
}

@test "config comments, whitespace, CRLF, quotes and missing final newline work" {
    local disk="$BATS_TEST_TMPDIR/disk = # one"
    mkdir "$disk"
    printf '  # comment\r\n\r\n REFRESH_INTERVAL = "008" \r\nDISK_PATH="%s"\r\nLAYOUT=\047micro\047' "$disk" > "$CONFIG"
    read_config
    [ "$REFRESH_INTERVAL" -eq 8 ]
    [ "$DISK_PATH" = "$disk" ]
    [ "$LAYOUT" = micro ]
}

@test "invalid entries each warn once and leave valid defaults intact" {
    local original_path=$PATH
    cat > "$CONFIG" <<'CONFIG'
REFRESH_INTERVAL=0
ENABLE_COLOR=2
CPU_WARN=-1
DISK_PATH=/nonexistent-pcc-config-test
NETWORK_INTERFACE=../../
LAYOUT=unknown
PATH=/untrusted
not a setting
CONFIG
    read_config 2> "$BATS_TEST_TMPDIR/errors"
    [ "$(grep -c '^Warning:' "$BATS_TEST_TMPDIR/errors")" -eq 8 ]
    [ "$REFRESH_INTERVAL|$ENABLE_COLOR|$CPU_WARN|$DISK_PATH|$NETWORK_INTERFACE|$LAYOUT" = '5|1|60|/||auto' ]
    [ "$PATH" = "$original_path" ]
}

@test "invalid threshold pairs warn once per metric and keep both defaults" {
    printf 'CPU_WARN=95\nCPU_CRIT=90\nTEMP_WARN=85\nTEMP_CRIT=85\n' > "$CONFIG"
    read_config 2> "$BATS_TEST_TMPDIR/errors"
    [ "$(grep -c '^Warning:' "$BATS_TEST_TMPDIR/errors")" -eq 2 ]
    [ "$CPU_WARN/$CPU_CRIT $TEMP_WARN/$TEMP_CRIT" = '60/85 70/85' ]
}

@test "config parsing never executes shell commands or expansions" {
    local marker="$BATS_TEST_TMPDIR/executed"
    printf 'REFRESH_INTERVAL=$(touch "%s")\nDISK_PATH=`touch "%s"`\ntouch "%s"\nCPU_WARN[$(touch "%s")]=1\n' "$marker" "$marker" "$marker" "$marker" > "$CONFIG"
    read_config 2> "$BATS_TEST_TMPDIR/errors"
    [ ! -e "$marker" ]
    [ "$REFRESH_INTERVAL|$DISK_PATH|$CPU_WARN" = '5|/|60' ]
    [ "$(grep -c '^Warning:' "$BATS_TEST_TMPDIR/errors")" -eq 4 ]
}

@test "numeric settings reject overflow and enforce each metric range" {
    local key value
    for key in REFRESH_INTERVAL CPU_WARN RAM_CRIT DISK_WARN SWAP_CRIT TEMP_WARN LOAD_CRIT; do
        for value in abc -1 1.5 99999999999999999999; do
            run valid_setting "$key" "$value"
            [ "$status" -ne 0 ]
            [ -z "$output" ]
        done
    done
    ! valid_setting CPU_WARN 101
    ! valid_setting TEMP_WARN 1000
    ! valid_setting LOAD_WARN 1000000
    ! valid_setting REFRESH_INTERVAL 0
    valid_setting CPU_WARN 0
    valid_setting CPU_CRIT 100
    valid_setting TEMP_CRIT 999
    valid_setting LOAD_CRIT 999999
    valid_setting REFRESH_INTERVAL 999999
}

@test "duplicate settings keep the last valid value and single thresholds use default partner" {
    printf 'REFRESH_INTERVAL=6\nREFRESH_INTERVAL=9\nREFRESH_INTERVAL=abc\nCPU_WARN=70\n' > "$CONFIG"
    read_config 2> "$BATS_TEST_TMPDIR/errors"
    [ "$REFRESH_INTERVAL" -eq 9 ]
    [ "$CPU_WARN/$CPU_CRIT" = '70/85' ]
    [ "$(grep -c '^Warning:' "$BATS_TEST_TMPDIR/errors")" -eq 1 ]
}

@test "an invalid config file type warns and does not stop startup" {
    mkdir "$CONFIG"
    read_config 2> "$BATS_TEST_TMPDIR/errors"
    [ "$(grep -c '^Warning:' "$BATS_TEST_TMPDIR/errors")" -eq 1 ]
    [ "$REFRESH_INTERVAL" -eq 5 ]
}

@test "main loads config before CLI overrides and normalizes decimal intervals" {
    local disk="$BATS_TEST_TMPDIR/cli disk"
    mkdir "$disk"
    printf 'REFRESH_INTERVAL=9\nENABLE_COLOR=1\nLAYOUT=wide\nDISK_PATH=/tmp\nCPU_WARN=70\n' > "$CONFIG"
    collect_sample() { :; }
    setup_colors() { :; }
    init_cpu_sample() { :; }
    sleep() { :; }
    render_dashboard() { printf '%s|%s|%s|%s|%s' "$REFRESH_INTERVAL" "$ENABLE_COLOR" "$LAYOUT" "$DISK_PATH" "$CPU_WARN"; }
    main --once --interval 008 --no-color --layout mini --disk "$disk" > "$BATS_TEST_TMPDIR/result"
    [ "$(cat "$BATS_TEST_TMPDIR/result")" = "8|0|mini|$disk|70" ]
}

@test "wide alias and layout flag obey command-line order" {
    parse_args --wide --layout tiny
    [ "$LAYOUT" = tiny ]
    parse_args --layout mini --wide
    [ "$LAYOUT" = wide ]
}

@test "new flags reject missing and invalid values before rendering" {
    local flag value
    for flag in --layout --disk; do
        run bash "$SCRIPT" "$flag"
        [ "$status" -eq 1 ]
        [[ "$output" == *'requires a value'* ]]
    done
    for value in auto invalid ''; do
        run bash "$SCRIPT" --layout "$value"
        [ "$status" -eq 1 ]
        [[ "$output" == Error:* ]]
    done
    run bash "$SCRIPT" --disk /nonexistent-pcc-config-test
    [ "$status" -eq 1 ]
    [[ "$output" == *'existing directory'* ]]
}

@test "each forced layout overrides a large terminal" {
    local spec layout marker
    for spec in 'compact SYS' 'mini PCC MINI' 'micro PCC MICRO' 'tiny PCC 5s' 'wide Top Processes'; do
        layout=${spec%% *}
        marker=${spec#* }
        run env TERM= COLUMNS=110 LINES=30 bash "$SCRIPT" --once --no-color --layout "$layout"
        [ "$status" -eq 0 ]
        [[ "$output" == *"$marker"* ]]
    done
}

@test "config layout forces mini without CLI flags" {
    printf 'LAYOUT=mini\n' > "$CONFIG"
    run env TERM= COLUMNS=110 LINES=30 bash "$SCRIPT" --once --no-color
    [ "$status" -eq 0 ]
    [[ "$output" == *'PCC MINI'* ]]
}

@test "configured thresholds reach colored metric renderers" {
    printf 'CPU_WARN=90\nCPU_CRIT=95\n' > "$CONFIG"
    read_config
    METRIC_CPU=90
    YELLOW=$'\e[33m' RED=$'\e[31m' GREEN=$'\e[32m' RESET=$'\e[0m'
    local renderer
    for renderer in system_panel compact_system_rows render_mini_dashboard render_micro_dashboard; do
        run "$renderer" 80 24
        [ "$status" -eq 0 ]
        [[ "$output" == *"${YELLOW}90%"* ]]
        [[ "$output" != *"${RED}90%"* ]]
    done
}

@test "help documents every config key and new flag" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    local key
    for key in REFRESH_INTERVAL ENABLE_COLOR DISK_PATH NETWORK_INTERFACE LAYOUT CPU_WARN CPU_CRIT RAM_WARN RAM_CRIT DISK_WARN DISK_CRIT TEMP_WARN TEMP_CRIT LOAD_WARN LOAD_CRIT SWAP_WARN SWAP_CRIT --layout --disk; do
        [[ "$output" == *"$key"* ]]
    done
}

@test "post-v3 settings validate ranges and CLI extra disks replace config selections" {
    printf '%s\n' 'HISTORY_ENABLED=0' 'HISTORY_SAMPLES=010' 'WARNINGS_ENABLED=0' \
        'ALERT_TRIGGER_SECONDS=001' 'ALERT_RECOVERY_SECONDS=3600' 'ALERT_PERCENT_MARGIN=0' \
        'ALERT_TEMP_MARGIN=999' 'EVENT_CAPACITY=1000' 'PRESSURE_ENABLED=0' \
        'BLOCK_DEVICE=nvme0n1' 'WATCH_DISK_1=/tmp' > "$CONFIG"
    read_config
    [ "$HISTORY_ENABLED $HISTORY_SAMPLES $WARNINGS_ENABLED $ALERT_TRIGGER_SECONDS" = '0 10 0 1' ]
    [ "$ALERT_RECOVERY_SECONDS $ALERT_PERCENT_MARGIN $ALERT_TEMP_MARGIN $EVENT_CAPACITY" = '3600 0 999 1000' ]
    [ "$PRESSURE_ENABLED $BLOCK_DEVICE ${WATCH_DISKS[*]}" = '0 nvme0n1 /tmp' ]
    parse_args --watch-disk / --watch-disk /tmp --view pressure --format json
    [ "${WATCH_DISKS[*]}" = '/ /tmp' ]
    [ "$VIEW $OUTPUT_FORMAT" = 'pressure json' ]
    ! valid_setting HISTORY_SAMPLES 9
    ! valid_setting HISTORY_SAMPLES 601
    ! valid_setting EVENT_CAPACITY 1001
    ! valid_setting ALERT_TRIGGER_SECONDS 0
    ! valid_setting BLOCK_DEVICE '../../bad'
    ! valid_setting WATCH_DISK_9 /tmp
}

@test "all added options reject missing and invalid values" {
    local flag
    for flag in --watch-disk --device --view --format --record; do
        run bash "$SCRIPT" "$flag"
        [ "$status" -eq 1 ]
        [[ "$output" == *'requires a'* ]]
    done
    run bash "$SCRIPT" --format invalid
    [ "$status" -eq 1 ]
    run bash "$SCRIPT" --view invalid
    [ "$status" -eq 1 ]
    run bash "$SCRIPT" --device '../../bad'
    [ "$status" -eq 1 ]
}
