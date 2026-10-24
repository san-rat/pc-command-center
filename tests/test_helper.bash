# Bats loads test files inside a function. Promote the script's associative
# state to global scope before fixtures assign nonnumeric keys in setup().
# This is test-runner plumbing; the executable itself stays Bash 4 compatible.
init_test_arrays() {
    declare -gA PREV_PROC_TICKS=()
    declare -gA SAMPLE_VALUE=() SAMPLE_STATE=() HISTORY_VALUES=()
    declare -gA ALERT_ACTIVE=() ALERT_PENDING=() ALERT_SINCE=() ALERT_LAST=() ALERT_UNKNOWN=()
    declare -gA PROC_NAME=() PROC_CPU=() PROC_MEM=() PREV_PROC_START=() PROC_DETAILS=()
    declare -gA PRESSURE_VALUES=()
    declare -gA STORAGE_PATH=() STORAGE_MOUNT=() STORAGE_TYPE=() STORAGE_VALUE=() STORAGE_STATE=() STORAGE_EXPECT=() STORAGE_ALIAS=()
}
