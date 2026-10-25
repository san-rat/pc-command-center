#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    ROOT="$BATS_TEST_DIRNAME/.."
    source "$ROOT/pc-command-center.sh"
}

@test "source install places pcc and its man page under the chosen prefix and uninstalls cleanly" {
    local stage="$BATS_TEST_TMPDIR/stage"
    run make -s -C "$ROOT" install PREFIX=/usr DESTDIR="$stage"
    [ "$status" -eq 0 ]
    [ -x "$stage/usr/bin/pcc" ]
    [ -f "$stage/usr/share/man/man1/pcc.1" ]
    [ -f "$stage/usr/share/doc/pc-command-center/examples/profiles/daily.conf" ]
    run "$stage/usr/bin/pcc" --version
    [ "$status" -eq 0 ]
    [ "$output" = "PC Command Center $VERSION" ]

    run make -s -C "$ROOT" uninstall PREFIX=/usr DESTDIR="$stage"
    [ "$status" -eq 0 ]
    [ ! -e "$stage/usr/bin/pcc" ]
    [ ! -e "$stage/usr/share/man/man1/pcc.1" ]
    [ ! -e "$stage/usr/share/doc/pc-command-center/examples/profiles/daily.conf" ]
}

@test "Debian package contains executable, manual, and current version metadata" {
    local output_dir="$BATS_TEST_TMPDIR/deb" artifact extracted
    run "$ROOT/packaging/build-deb.sh" "$VERSION" "$output_dir"
    [ "$status" -eq 0 ]
    artifact="$output_dir/pc-command-center_${VERSION}_all.deb"
    [ -f "$artifact" ]
    [ "$(dpkg-deb -f "$artifact" Package)" = pc-command-center ]
    [ "$(dpkg-deb -f "$artifact" Version)" = "$VERSION" ]
    [ "$(dpkg-deb -f "$artifact" Architecture)" = all ]
    extracted="$BATS_TEST_TMPDIR/extracted"
    dpkg-deb -x "$artifact" "$extracted"
    [ -x "$extracted/usr/bin/pcc" ]
    [ -f "$extracted/usr/share/man/man1/pcc.1" ]
    [ -f "$extracted/usr/share/doc/pc-command-center/examples/profiles/development.conf" ]
    run "$extracted/usr/bin/pcc" --version
    [ "$status" -eq 0 ]
    [ "$output" = "PC Command Center $VERSION" ]
}

@test "release notes select only the matching changelog section" {
    run "$ROOT/packaging/release-notes.sh" "$VERSION"
    [ "$status" -eq 0 ]
    [[ "$output" == *'named profiles'* ]]
    [[ "$output" != *'Add live CPU/memory process sorting'* ]]
    run "$ROOT/packaging/release-notes.sh" 9.9.9
    [ "$status" -ne 0 ]
}
