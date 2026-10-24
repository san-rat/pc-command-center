#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/../pc-command-center.sh"
source "$BATS_TEST_DIRNAME/test_helper.bash"

setup() {
    init_test_arrays
    timeout() { shift 3; "$@"; }
    read_mounts() { MOUNT_PATHS=(/); MOUNT_DEVS=(8:1); MOUNT_TYPES=(ext4); }
    df() { printf 'header\n10000 2500 7500 25%% 100 50 50 50%%\n'; }
}

@test "filesystem aliases are deduplicated and inode/capacity data share a query" {
    WATCH_DISKS=(/tmp)
    collect_storage
    [ "${#STORAGE_IDS[@]}" -eq 1 ]
    [ "${STORAGE_ALIAS[8:1]}" = ' /tmp' ]
    [ "${STORAGE_VALUE[8:1,7]}" = 50 ]
    [ "${SAMPLE_VALUE[disk_used_bytes]}" -eq 2500 ]
}

@test "unmounted or missing selections never silently become the root filesystem" {
    DISK_PATH=/tmp
    STORAGE_EXPECT[/tmp]=8:2
    collect_storage
    [ "${SAMPLE_STATE[disk]}" = unavailable ]
    DISK_PATH=/does-not-exist-pcc
    collect_storage
    [ "${SAMPLE_STATE[disk]}" = unavailable ]
}

@test "remote filesystems are not probed and zero inodes remain unsupported" {
    read_mounts() { MOUNT_PATHS=(/); MOUNT_DEVS=(0:1); MOUNT_TYPES=(nfs); }
    df() { return 99; }
    collect_storage
    [ "${SAMPLE_STATE[disk]}" = unsupported ]
    read_mounts() { MOUNT_PATHS=(/); MOUNT_DEVS=(0:1); MOUNT_TYPES=(tmpfs); }
    df() { printf 'header\n10000 0 10000 0%% 0 0 0 -\n'; }
    collect_storage
    VIEW_ROWS=(); storage_view_rows
    [[ "${VIEW_ROWS[*]}" == *'Inodes N/A'* ]]
}

@test "device rates use 512-byte sectors and reset on rollback or identity changes" {
    BLOCK_DEVICE=sda
    TEST_ID=8:0:sda TEST_READ=100 TEST_WRITE=200
    read_device_counters() { printf '%s %s %s\n' "$TEST_ID" "$TEST_READ" "$TEST_WRITE"; }
    SAMPLE_TIME_MS=1000; collect_device
    [ "$DEVICE_STATE" = warming ]
    SAMPLE_TIME_MS=3000 TEST_READ=104 TEST_WRITE=208; collect_device
    [ "$DEVICE_READ_RATE $DEVICE_WRITE_RATE $DEVICE_STATE" = '1024 2048 valid' ]
    SAMPLE_TIME_MS=4000 TEST_READ=1; collect_device
    [ "$DEVICE_STATE" = warming ]
    SAMPLE_TIME_MS=5000 TEST_ID=8:1:sda; collect_device
    [ "$DEVICE_STATE" = warming ]
}

@test "pressure tolerates missing fields and omits system CPU full" {
    read_pressure_source() {
        [ "$1" != io ] || return 1
        printf 'some avg10=1.23 avg60=invalid avg300=100.01 total=42\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n'
    }
    collect_pressure
    [ "${PRESSURE_VALUES[cpu,some,avg10]}" = 1.23 ]
    [ -z "${PRESSURE_VALUES[cpu,some,avg60]:-}" ]
    [ -z "${PRESSURE_VALUES[cpu,some,avg300]:-}" ]
    [ -z "${PRESSURE_VALUES[cpu,full,avg10]:-}" ]
    [ "${PRESSURE_VALUES[memory,full,avg10]}" = 0.00 ]
    PRESSURE_ENABLED=0; collect_pressure
    [ "${#PRESSURE_VALUES[@]}" -eq 0 ]
}
