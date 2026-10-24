#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    SCRIPT="$BATS_TEST_DIRNAME/../pc-command-center.sh"
    SAMPLE_SEQUENCE=1 SAMPLE_TIME_MS=2000 SAMPLE_START_MS=1000 SAMPLE_INTERVAL_MS=1000
    SAMPLE_UTC=2026-10-24T12:00:00Z SESSION_ID=test
    sample_set cpu 25; sample_set rx '' warming
}

@test "JSON schema parses independently and distinguishes zero from unavailable" {
    DISK_PATH=$'/odd "name"\n\e\xff'
    sample_set ram 0
    json_snapshot > "$BATS_TEST_TMPDIR/sample.json"
    python3 - "$BATS_TEST_TMPDIR/sample.json" <<'PY'
import json,sys,urllib.parse
v=json.load(open(sys.argv[1]))
assert v['schema_version']==1 and v['cpu']==25 and v['ram']==0
assert v['rx'] is None and v['rx_state']=='warming'
assert urllib.parse.unquote_to_bytes(v['disk_path'])==b'/odd "name"\n\x1b\xff'
assert v['interval_ms']==1000
PY
}

@test "CSV has stable columns and text bytes are reversible and formula-neutral" {
    DISK_PATH=$'=1+2,"quoted"\n'
    { csv_line 1; csv_line; } > "$BATS_TEST_TMPDIR/sample.csv"
    python3 - "$BATS_TEST_TMPDIR/sample.csv" <<'PY'
import csv,sys,urllib.parse
rows=list(csv.DictReader(open(sys.argv[1],newline='')))
assert len(rows)==1 and None not in rows[0]
v=rows[0]
assert v['cpu']=='25' and v['rx']=='' and v['rx_state']=='warming'
assert v['disk_path'].startswith('%3D')
assert urllib.parse.unquote_to_bytes(v['disk_path'])==b'=1+2,"quoted"\n'
PY
}

@test "recording creates a private new file and never overwrites existing destinations" {
    RECORD_PATH="$BATS_TEST_TMPDIR/session.csv"
    start_recording
    record_sample
    cleanup
    [ "$(stat -c %a "$RECORD_PATH")" = 600 ]
    [ "$(wc -l < "$RECORD_PATH")" -eq 2 ]
    ! start_recording
    [ "$(wc -l < "$RECORD_PATH")" -eq 2 ]
    ln -s "$BATS_TEST_TMPDIR/absent" "$BATS_TEST_TMPDIR/link"
    RECORD_PATH="$BATS_TEST_TMPDIR/link"
    ! start_recording
    [ ! -e "$BATS_TEST_TMPDIR/absent" ]
}

@test "recording limit and write failure stop recording with failure exit status" {
    RECORD_PATH="$BATS_TEST_TMPDIR/limited.csv"
    start_recording
    RECORD_LIMIT=$RECORD_BYTES
    record_sample
    [ "$EXIT_STATUS" -eq 1 ]
    [ -z "$RECORD_FD" ]
    [[ "$RECORD_ERROR" == *'limit'* ]]
    [ "$(wc -l < "$RECORD_PATH")" -eq 1 ]
    RECORD_PATH="$BATS_TEST_TMPDIR/failure.csv" RECORD_LIMIT=104857600 RECORD_ERROR=''
    start_recording
    exec 9>&-
    record_sample
    [[ "$RECORD_ERROR" == *'write failed'* ]]
}

@test "CLI formats produce parser-valid snapshots and recording rejects non-TTY" {
    run bash "$SCRIPT" --format json
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | python3 -c 'import json,sys; assert json.load(sys.stdin)["sample_sequence"]==1'
    run bash "$SCRIPT" --record "$BATS_TEST_TMPDIR/unwanted.csv"
    [ "$status" -eq 1 ]
    [ ! -e "$BATS_TEST_TMPDIR/unwanted.csv" ]
}
