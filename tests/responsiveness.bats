#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() { init_test_arrays; }

@test "ANSI width helpers preserve multi-color styles and need no sed subprocess" {
    sed() { echo unexpected-sed >&2; return 1; }
    local styled=$'\e[1;31mred\e[m / \e[0;32mgreen\e[0m'
    [ "$(strip_ansi "$styled")" = 'red / green' ]
    [ "$(visible_length "$styled")" -eq 11 ]
    [ "$(pad_ansi "$styled" 14)" = "$styled   " ]
    [ "$(pad_ansi "$styled" 8)" = 'red / g~' ]
    [ "$(center_ansi "$styled" 13)" = " $styled " ]
}

@test "ANSI removal matches existing SGR scope and leaves other text intact" {
    [ "$(strip_ansi $'plain\e[2Jcontrol')" = $'plain\e[2Jcontrol' ]
    [ "$(strip_ansi $'\e[31mone\e[31mtwo\e[0m')" = onetwo ]
    [ "$(strip_ansi 'literal [31m')" = 'literal [31m' ]
}

@test "direct fitted-line output preserves exact padding newline and truncation" {
    print_fit_line 5 abc > "$BATS_TEST_TMPDIR/line"
    [ "$(wc -c < "$BATS_TEST_TMPDIR/line")" -eq 6 ]
    [ "$(cat "$BATS_TEST_TMPDIR/line")" = 'abc  ' ]
    [ "$(print_fit_line 3 abcdef)" = 'ab~' ]
}
