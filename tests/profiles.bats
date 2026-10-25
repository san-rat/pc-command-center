#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    SCRIPT="$BATS_TEST_DIRNAME/../pc-command-center.sh"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    PROFILE_DIR="$XDG_CONFIG_HOME/pc-command-center/profiles"
    mkdir -p "$PROFILE_DIR"
    CONFIG="$XDG_CONFIG_HOME/pc-command-center.conf"
    setup_colors() { :; }
    init_cpu_sample() { :; }
    sleep() { :; }
    collect_sample() { :; }
    render_dashboard() { printf '%s|%s|%s|%s|%s' "$REFRESH_INTERVAL" "$LAYOUT" "$CPU_WARN/$CPU_CRIT" "$PROFILE" "$DISK_PATH"; }
}

@test "profile overrides base and CLI wins regardless of profile option position" {
    printf 'REFRESH_INTERVAL=9\nLAYOUT=mini\nCPU_WARN=70\n' > "$CONFIG"
    printf 'REFRESH_INTERVAL=3\nLAYOUT=wide\nCPU_CRIT=95\n' > "$PROFILE_DIR/development.conf"
    main --once --interval 008 --profile development > "$BATS_TEST_TMPDIR/result"
    [ "$(cat "$BATS_TEST_TMPDIR/result")" = '8|wide|70/95|development|/' ]
}

@test "without a profile existing base configuration behavior is unchanged" {
    printf 'REFRESH_INTERVAL=9\n' > "$CONFIG"
    main --once > "$BATS_TEST_TMPDIR/result"
    [ "$(cat "$BATS_TEST_TMPDIR/result")" = '9|auto|60/85||/' ]
}

@test "last profile wins and layers validate threshold pairs against inherited values" {
    printf 'CPU_WARN=90\nCPU_CRIT=95\n' > "$CONFIG"
    printf 'REFRESH_INTERVAL=2\n' > "$PROFILE_DIR/first.conf"
    printf 'REFRESH_INTERVAL=7\nCPU_CRIT=80\n' > "$PROFILE_DIR/second.conf"
    main --once --profile first --profile second > "$BATS_TEST_TMPDIR/result" 2> "$BATS_TEST_TMPDIR/errors"
    [ "$(cat "$BATS_TEST_TMPDIR/result")" = '7|auto|90/95|second|/' ]
    [ "$CONFIG_WARNINGS" -eq 1 ]
    [ "$(grep -c '^Warning:' "$BATS_TEST_TMPDIR/errors")" -eq 1 ]
}

@test "profile selection skips values of other options" {
    select_profile --record --profile --once
    [ -z "$PROFILE" ]
    select_profile --disk /tmp --profile daily --interval 2
    [ "$PROFILE" = daily ]
}

@test "profile names reject traversal expansions empty values and excess length" {
    local name
    for name in '' ../daily a/b '.hidden' 'daily.conf' 'a b' '$(touch bad)' "$(printf '%065d' 0)"; do
        run bash "$SCRIPT" --profile "$name" --once
        [ "$status" -eq 1 ]
        [[ "$output" == *'invalid profile name'* ]]
    done
    run bash "$SCRIPT" --profile
    [ "$status" -eq 1 ]
    [[ "$output" == *'requires a name'* ]]
    valid_profile_name development
    valid_profile_name low-power_2
}

@test "a missing profile is a clear error rather than silently using defaults" {
    run bash "$SCRIPT" --profile missing --once
    [ "$status" -eq 1 ]
    [[ "$output" == *'cannot read profile missing'* ]]
    mkdir "$PROFILE_DIR/directory.conf"
    run bash "$SCRIPT" --profile directory --once
    [ "$status" -eq 1 ]
}

@test "profile files use literal parsing and cannot execute commands or select another profile" {
    local marker="$BATS_TEST_TMPDIR/executed"
    printf 'REFRESH_INTERVAL=$(touch "%s")\nPROFILE=other\nLAYOUT="micro"\n' "$marker" > "$PROFILE_DIR/safe.conf"
    main --once --profile safe > "$BATS_TEST_TMPDIR/result" 2> "$BATS_TEST_TMPDIR/errors"
    [ ! -e "$marker" ]
    [ "$(cat "$BATS_TEST_TMPDIR/result")" = '5|micro|60/85|safe|/' ]
    [ "$CONFIG_WARNINGS" -eq 2 ]
}

@test "list-profiles lists only valid regular profile names without collecting metrics" {
    touch "$PROFILE_DIR/daily.conf" "$PROFILE_DIR/low-power.conf" "$PROFILE_DIR/not a name.conf"
    mkdir "$PROFILE_DIR/directory.conf"
    run bash "$SCRIPT" --list-profiles
    [ "$status" -eq 0 ]
    [[ "$output" == *'daily'*'low-power'* ]]
    [[ "$output" != *'not a name'* ]]
    [[ "$output" != *'  directory'* ]]
    [[ "$output" != *'PC COMMAND CENTER'* ]]
}

@test "CLI extra disks still replace inherited profile selections" {
    printf 'WATCH_DISK_1=/tmp\n' > "$PROFILE_DIR/daily.conf"
    main --once --profile daily --watch-disk / > /dev/null
    [ "${WATCH_DISKS[*]}" = / ]
}
