#!/bin/bash

# PC Command Center
# A lightweight terminal dashboard for Ubuntu/Linux systems.

VERSION="4.1.0"
REFRESH_INTERVAL=5
ENABLE_COLOR=1
ONCE=0
LAYOUT=auto
DISK_PATH=/
NETWORK_INTERFACE=""
PROCESS_SORT=cpu
PROFILE=""
DOCTOR=0
LIST_PROFILES=0
CONFIG_WARNINGS=0
PLAIN_TEXT=""
PAUSED=0
HELP_VISIBLE=0
CPU_WARN=60
CPU_CRIT=85
RAM_WARN=75
RAM_CRIT=90
DISK_WARN=75
DISK_CRIT=90
TEMP_WARN=70
TEMP_CRIT=85
LOAD_WARN=70
LOAD_CRIT=100
SWAP_WARN=50
SWAP_CRIT=80
LIVE_MODE=0
TERMINAL_READY=0
STTY_STATE=""
PREV_CPU_IDLE=0
PREV_CPU_TOTAL=0
CPU_DIFF_TOTAL=0
CPU_SAMPLE_STATE=warming
CPU_COUNT=1
CPU_IDLE=0
CPU_TOTAL=0
CPU_CORE_TOTALS=()
CPU_CORE_IDLES=()
PREV_CORE_TOTALS=()
PREV_CORE_IDLES=()
METRIC_CORE_CPUS=()
NEXT_DRAW=0
RESIZE_PENDING=1
TERM_COLS=80
TERM_LINES=24
METRIC_CPU=0
METRIC_MEM_USED=""
METRIC_MEM_TOTAL=""
METRIC_MEM_PERCENT=0
METRIC_SWAP_USED=0B
METRIC_SWAP_TOTAL=0B
METRIC_SWAP_PERCENT=0
METRIC_DISK_USED=""
METRIC_DISK_TOTAL=""
METRIC_DISK_AVAILABLE=""
METRIC_DISK_PERCENT=0
METRIC_DISK_LABEL=ROOT
METRIC_TEMP="Not available"
METRIC_TEMP_SHORT="N/A"
METRIC_TEMP_PERCENT=0
METRIC_LOAD=""
METRIC_LOAD_ONE=0
METRIC_LOAD_PERCENT=0
METRIC_PROCESS_COUNT=0
METRIC_PROCESSES=""
METRIC_INTERFACE="No active IPv4"
METRIC_GATEWAY=""
METRIC_INTERFACES=()
METRIC_ALL_INTERFACES=()
METRIC_UPTIME=""
METRIC_HOST=""
METRIC_USER=""
METRIC_TIME=""
METRIC_DEFAULT_IFACE=""
METRIC_NET_INTERFACE=""
METRIC_NET_RX_RATE=N/A
METRIC_NET_TX_RATE=N/A
PREV_NET_INTERFACE=""
PREV_NET_RX=0
PREV_NET_TX=0
PREV_NET_TIME=0
METRIC_PROCESS_CPU_MODE=avg
METRIC_BATTERY=""
declare -A PREV_PROC_TICKS=()

# Session samples and optional investigation features.
HISTORY_ENABLED=1
HISTORY_SAMPLES=60
WARNINGS_ENABLED=1
ALERT_TRIGGER_SECONDS=30
ALERT_RECOVERY_SECONDS=15
ALERT_PERCENT_MARGIN=5
ALERT_TEMP_MARGIN=5
EVENT_CAPACITY=100
PRESSURE_ENABLED=1
VIEW=overview
OUTPUT_FORMAT=terminal
RECORD_PATH=""
RECORD_FD=""
RECORD_BYTES=0
RECORD_LIMIT=104857600
RECORD_ERROR=""
EXIT_STATUS=0
SESSION_ID=""
SAMPLE_SEQUENCE=0
SAMPLE_TIME_MS=0
SAMPLE_START_MS=0
SAMPLE_INTERVAL_MS=0
SAMPLE_UTC=""
SAMPLE_GAP=0
BASELINE_RESET=0
CLOCK_MS=0
HISTORY_HEAD=0
HISTORY_COUNT=0
HISTORY_INTERFACE=""
EVENT_HEAD=0
EVENT_COUNT=0
EVENTS_VISIBLE=0
PROCESS_FILTER=""
FILTER_EDITING=0
FILTER_INPUT=""
SELECTED_PROCESS=""
PROCESS_DETAIL=0
SHOW_ARGUMENTS=0
PROCESS_OFFSET=0
STORAGE_OFFSET=0
EVENT_OFFSET=0
DETAIL_STATUS=warming
DETAIL_ARGUMENTS=""
BLOCK_DEVICE=""
PREV_DEVICE=""
PREV_DEVICE_READ=0
PREV_DEVICE_WRITE=0
PREV_DEVICE_TIME=0
DEVICE_READ_RATE=""
DEVICE_WRITE_RATE=""
DEVICE_STATE=unavailable
WATCH_DISKS=()
CLI_WATCH_DISKS=0
PROCESS_IDS=()
FILTERED_IDS=()
HISTORY_TIMES=()
HISTORY_GAPS=()
EVENTS=()
VIEW_ROWS=()
declare -A SAMPLE_VALUE=() SAMPLE_STATE=()
declare -A HISTORY_VALUES=()
declare -A ALERT_ACTIVE=() ALERT_PENDING=() ALERT_SINCE=() ALERT_LAST=() ALERT_UNKNOWN=()
declare -A PROC_NAME=() PROC_CPU=() PROC_MEM=() PREV_PROC_START=() PROC_DETAILS=()
declare -A PRESSURE_VALUES=()
STORAGE_IDS=()
declare -A STORAGE_PATH=() STORAGE_MOUNT=() STORAGE_TYPE=() STORAGE_VALUE=() STORAGE_STATE=() STORAGE_EXPECT=() STORAGE_ALIAS=()
MOUNT_PATHS=() MOUNT_DEVS=() MOUNT_TYPES=()

RESET=""
BOLD=""
DIM=""
RED=""
GREEN=""
YELLOW=""
BLUE=""
CYAN=""

usage() {
    cat <<'EOF'
PC Command Center

Usage:
  ./pc-command-center.sh [options]

Options:
  --interval SECONDS  Set the refresh interval (1-999999). Default: 5
  --no-color          Disable terminal colors
  --once              Print one dashboard snapshot and exit
  --layout LAYOUT     Force compact, mini, micro, tiny, or wide layout
  --wide              Alias for --layout wide
  --disk PATH         Monitor the filesystem containing PATH. Default: /
  --watch-disk PATH   Add a filesystem to Storage (up to eight; repeatable)
  --device NAME       Show explicit block device read/write rates
  --view VIEW         overview|processes|storage|network|pressure
  --format FORMAT     terminal|json|csv; json/csv imply one-shot
  --record PATH       Record live samples to a new CSV file (100 MiB limit)
  --profile NAME      Load a named profile before CLI overrides (last name wins)
  --list-profiles     List available named profiles and exit
  --doctor            Diagnose dependencies, sources, and configuration; no TUI
  --version           Show the version and exit
  --help              Show this help message

Live telemetry:
  Network RX/TX rates use byte-counter deltas for the selected/default route interface.
  Live process CPU uses interval deltas; --once labels ps lifetime averages as AVG.
  Battery and per-core CPU readings appear when hardware data is available (wide view).

Configuration:
  ~/.config/pc-command-center.conf (or $XDG_CONFIG_HOME/pc-command-center.conf)
  Defaults < base config < selected profile < CLI flags. Literal KEY=value only.
  Profiles: $XDG_CONFIG_HOME/pc-command-center/profiles/NAME.conf (or ~/.config/...).
  Names: 1..64 letters/digits/underscore/hyphen, starting with a letter or digit.
  Profile selection is CLI-only; files never execute shell commands.
  REFRESH_INTERVAL=1..999999, ENABLE_COLOR=0|1, DISK_PATH=directory,
  NETWORK_INTERFACE=interface (empty for all), LAYOUT=auto|compact|mini|micro|tiny|wide.
  CPU_WARN/CPU_CRIT=60/85, RAM_WARN/RAM_CRIT=75/90, DISK_WARN/DISK_CRIT=75/90,
  TEMP_WARN/TEMP_CRIT=70/85 (Celsius), LOAD_WARN/LOAD_CRIT=70/100,
  SWAP_WARN/SWAP_CRIT=50/80. These pairs show defaults; set each key separately.
  Thresholds: CPU/RAM/DISK/SWAP 0..100, TEMP 0..999, LOAD 0..999999; WARN < CRIT.
  HISTORY_ENABLED=1, HISTORY_SAMPLES=60 (10..600), WARNINGS_ENABLED=1,
  ALERT_TRIGGER_SECONDS=30, ALERT_RECOVERY_SECONDS=15 (1..3600),
  ALERT_PERCENT_MARGIN=5 (0..100), ALERT_TEMP_MARGIN=5 (0..999),
  EVENT_CAPACITY=100 (10..1000), PRESSURE_ENABLED=1, BLOCK_DEVICE=name,
  WATCH_DISK_1 through WATCH_DISK_8=directory. Boolean settings accept 0|1.
  Invalid entries warn once and are ignored; invalid threshold pairs are ignored.

Live controls:
  q     Quit
  r     Refresh now
  +     Refresh faster, down to 1 second
  -     Refresh slower
  c/m   Sort processes by CPU/memory
  p     Pause or resume automatic refresh
  ?     Show help; any key dismisses it
  n     Cycle the active network interface
  1-5   Overview, Processes, Storage, Network, Pressure
  e     Toggle recent warning events
  j/k   Move process selection or scroll storage/events
  /     Edit a literal process filter (Enter applies; Escape cancels)
  Enter Open selected process details; Escape closes details
  a     Toggle full arguments in process details (next sample; r refreshes)

Samples and output:
  Resize, sorting, and view changes repaint the latest sample without collection.
  History is session-only; ? means unavailable and | marks a sampling gap.
  Pausing/help suspend sampling; unobserved time never confirms a warning.
  JSON/CSV schema 1 uses raw units, explicit states, and percent-encoded text bytes.
  Recording requires a TTY, never replaces files, and stops on write/size failure.
EOF
}

die() {
    echo "Error: $*" >&2
    echo "Run ./pc-command-center.sh --help for usage." >&2
    exit 1
}

valid_number() {
    [[ "$1" =~ ^[0-9]{1,6}$ ]] && ((10#$1 >= $2 && 10#$1 <= $3))
}

valid_setting() {
    local key="$1" value="$2"

    case "$key" in
        REFRESH_INTERVAL) valid_number "$value" 1 999999 ;;
        ENABLE_COLOR|HISTORY_ENABLED|WARNINGS_ENABLED|PRESSURE_ENABLED) [[ "$value" == 0 || "$value" == 1 ]] ;;
        HISTORY_SAMPLES) valid_number "$value" 10 600 ;;
        EVENT_CAPACITY) valid_number "$value" 10 1000 ;;
        ALERT_TRIGGER_SECONDS|ALERT_RECOVERY_SECONDS) valid_number "$value" 1 3600 ;;
        ALERT_PERCENT_MARGIN) valid_number "$value" 0 100 ;;
        ALERT_TEMP_MARGIN) valid_number "$value" 0 999 ;;
        WATCH_DISK_[1-8]) [ -d "$value" ] ;;
        BLOCK_DEVICE) [[ -z "$value" || "$value" =~ ^[a-zA-Z0-9_.!-]{1,128}$ ]] ;;
        CPU_WARN|CPU_CRIT|RAM_WARN|RAM_CRIT|DISK_WARN|DISK_CRIT|SWAP_WARN|SWAP_CRIT)
            valid_number "$value" 0 100 ;;
        TEMP_WARN|TEMP_CRIT) valid_number "$value" 0 999 ;;
        LOAD_WARN|LOAD_CRIT) valid_number "$value" 0 999999 ;;
        DISK_PATH) [ -d "$value" ] ;;
        NETWORK_INTERFACE)
            [[ -z "$value" || ( "$value" =~ ^[a-zA-Z0-9_.:-]{1,15}$ && -e "/sys/class/net/$value" && "$value" != . && "$value" != .. ) ]] ;;
        LAYOUT)
            case "$value" in auto|compact|mini|micro|tiny|wide) return 0 ;; *) return 1 ;; esac ;;
        *) return 1 ;;
    esac
}

read_config() {
    local file="${1:-${XDG_CONFIG_HOME:-$HOME/.config}/pc-command-center.conf}"
    local line key value metric warn_key crit_key warn crit
    local line_number=0
    local -A thresholds=()

    [ -e "$file" ] || return 0
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        CONFIG_WARNINGS=$((CONFIG_WARNINGS + 1))
        printf 'Warning: cannot read config %s; ignored\n' "$file" >&2
        return 0
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        line_number=$((line_number + 1))
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        [[ -z "$line" || "$line" == \#* ]] && continue
        if ! [[ "$line" =~ ^([A-Z][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            CONFIG_WARNINGS=$((CONFIG_WARNINGS + 1))
            printf 'Warning: %s:%s: invalid config entry; ignored\n' "$file" "$line_number" >&2
            continue
        fi
        key=${BASH_REMATCH[1]}
        value=${BASH_REMATCH[2]}
        if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
            value=${value:1:${#value}-2}
        fi
        if ! valid_setting "$key" "$value"; then
            CONFIG_WARNINGS=$((CONFIG_WARNINGS + 1))
            printf 'Warning: %s:%s: invalid %s; ignored\n' "$file" "$line_number" "$key" >&2
            continue
        fi
        case "$key" in
            *_WARN|*_CRIT) thresholds[$key]=$((10#$value)) ;;
            REFRESH_INTERVAL|HISTORY_SAMPLES|EVENT_CAPACITY|ALERT_TRIGGER_SECONDS|ALERT_RECOVERY_SECONDS|ALERT_PERCENT_MARGIN|ALERT_TEMP_MARGIN)
                printf -v "$key" '%s' "$((10#$value))" ;;
            WATCH_DISK_[1-8]) WATCH_DISKS[${key##*_} - 1]=$value ;;
            *) printf -v "$key" '%s' "$value" ;;
        esac
    done < "$file"

    # Validate complete pairs so their order in the file does not matter.
    for metric in CPU RAM DISK TEMP LOAD SWAP; do
        warn_key=${metric}_WARN
        crit_key=${metric}_CRIT
        warn=${thresholds[$warn_key]:-${!warn_key}}
        crit=${thresholds[$crit_key]:-${!crit_key}}
        if [ "$warn" -lt "$crit" ]; then
            printf -v "$warn_key" '%s' "$warn"
            printf -v "$crit_key" '%s' "$crit"
        else
            CONFIG_WARNINGS=$((CONFIG_WARNINGS + 1))
            printf 'Warning: %s: invalid %s thresholds; pair ignored\n' "$file" "$metric" >&2
        fi
    done
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --profile)
                [ "$#" -ge 2 ] || die "--profile requires a name"
                valid_profile_name "$2" || die "invalid profile name (letters, digits, underscore, hyphen; max 64)"
                PROFILE=$2; shift 2 ;;
            --doctor) DOCTOR=1; shift ;;
            --list-profiles) LIST_PROFILES=1; shift ;;
            --interval)
                [ "$#" -ge 2 ] || die "--interval requires a value"
                [[ "$2" =~ ^[0-9]{1,6}$ ]] || die "--interval must be a positive integer (1-999999)"
                [ "$2" -ge 1 ] || die "--interval must be at least 1"
                REFRESH_INTERVAL=$((10#$2))
                shift 2
                ;;
            --no-color)
                ENABLE_COLOR=0
                shift
                ;;
            --once)
                ONCE=1
                shift
                ;;
            --wide)
                LAYOUT=wide
                shift
                ;;
            --layout)
                [ "$#" -ge 2 ] || die "--layout requires a value"
                case "$2" in
                    compact|mini|micro|tiny|wide) LAYOUT="$2" ;;
                    *) die "--layout must be compact, mini, micro, tiny, or wide" ;;
                esac
                shift 2
                ;;
            --disk)
                [ "$#" -ge 2 ] || die "--disk requires a value"
                valid_setting DISK_PATH "$2" || die "--disk must be an existing directory"
                DISK_PATH="$2"
                shift 2
                ;;
            --watch-disk)
                [ "$#" -ge 2 ] || die "--watch-disk requires a value"
                [ -d "$2" ] || die "--watch-disk must be an existing directory"
                if [ "$CLI_WATCH_DISKS" -eq 0 ]; then WATCH_DISKS=(); CLI_WATCH_DISKS=1; fi
                [ "${#WATCH_DISKS[@]}" -lt 8 ] || die "at most eight --watch-disk paths are supported"
                WATCH_DISKS+=("$2"); shift 2 ;;
            --device)
                [ "$#" -ge 2 ] || die "--device requires a value"
                if ! valid_setting BLOCK_DEVICE "$2" || [ -z "$2" ]; then die "invalid device name"; fi
                BLOCK_DEVICE=$2; shift 2 ;;
            --view)
                [ "$#" -ge 2 ] || die "--view requires a value"
                case "$2" in overview|processes|storage|network|pressure) VIEW=$2 ;; *) die "invalid view" ;; esac
                shift 2 ;;
            --format)
                [ "$#" -ge 2 ] || die "--format requires a value"
                case "$2" in terminal|json|csv) OUTPUT_FORMAT=$2 ;; *) die "--format must be terminal, json, or csv" ;; esac
                shift 2 ;;
            --record)
                [ "$#" -ge 2 ] || die "--record requires a path"
                [ -n "$2" ] || die "--record requires a path"
                RECORD_PATH=$2; shift 2 ;;
            --version)
                printf 'PC Command Center %s\n' "$VERSION"
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                die "unknown option: $1"
                ;;
        esac
    done
}

tput_cmd() {
    if command -v tput >/dev/null 2>&1 && [ -n "${TERM:-}" ]; then
        tput "$@" 2>/dev/null || true
    fi
}

setup_colors() {
    local colors

    if [ "$ENABLE_COLOR" -eq 0 ] || [ ! -t 1 ]; then
        return
    fi

    colors=$(tput_cmd colors)
    if [[ "$colors" =~ ^[0-9]+$ ]] && [ "$colors" -ge 8 ]; then
        RESET=$(tput_cmd sgr0)
        BOLD=$(tput_cmd bold)
        DIM=$(tput_cmd dim)
        RED=$(tput_cmd setaf 1)
        GREEN=$(tput_cmd setaf 2)
        YELLOW=$(tput_cmd setaf 3)
        BLUE=$(tput_cmd setaf 4)
        CYAN=$(tput_cmd setaf 6)
    fi
}

cleanup() {
    if [ -n "$RECORD_FD" ]; then exec 9>&-; RECORD_FD=""; fi
    if [ "$TERMINAL_READY" -eq 1 ]; then
        if [ -n "$STTY_STATE" ]; then
            stty "$STTY_STATE" 2>/dev/null || true
        fi
        tput_cmd cnorm
        tput_cmd rmcup
    fi
}

setup_terminal() {
    STTY_STATE=$(stty -g 2>/dev/null || true)
    tput_cmd smcup
    tput_cmd civis
    tput_cmd clear
    stty -echo -icanon min 0 time 0 2>/dev/null || true
    TERMINAL_READY=1
}

repeat_char() {
    local char="$1"
    local count="$2"
    local out=""

    if [ "$count" -le 0 ]; then
        return
    fi

    printf -v out '%*s' "$count" ''
    printf '%s' "${out// /$char}"
}

# Use one shared result to avoid launching a process for every width check.
strip_ansi_text() {
    local pattern=$'\e''\[[0-9;]*m'
    PLAIN_TEXT=$1
    while [[ "$PLAIN_TEXT" =~ $pattern ]]; do
        PLAIN_TEXT=${PLAIN_TEXT/"${BASH_REMATCH[0]}"/}
    done
}

strip_ansi() {
    strip_ansi_text "$1"
    printf '%s' "$PLAIN_TEXT"
}

visible_length() {
    local plain
    strip_ansi_text "$1"
    plain=$PLAIN_TEXT
    printf '%s' "${#plain}"
}

pad_ansi() {
    local text="$1"
    local width="$2"
    local plain
    local visible

    [ "$width" -lt 0 ] && width=0

    strip_ansi_text "$text"
    plain=$PLAIN_TEXT
    visible=${#plain}

    if [ "$visible" -gt "$width" ]; then
        if [ "$width" -le 1 ]; then
            printf '%s' "${plain:0:$width}"
        else
            printf '%s~' "${plain:0:$((width - 1))}"
        fi
        return
    fi

    printf '%s%*s' "$text" "$((width - visible))" ''
}

center_ansi() {
    local text="$1"
    local width="$2"
    local visible
    local left
    local right

    strip_ansi_text "$text"
    visible=${#PLAIN_TEXT}
    if [ "$visible" -ge "$width" ]; then
        pad_ansi "$text" "$width"
        return
    fi

    left=$(((width - visible) / 2))
    right=$((width - visible - left))
    printf '%*s%s%*s' "$left" '' "$text" "$right" ''
}

colorize() {
    local color="$1"
    local text="$2"

    printf '%s%s%s' "$color" "$text" "$RESET"
}

status_color() {
    local value="$1"
    local warn="$2"
    local crit="$3"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s' "$DIM"
    elif [ "$value" -ge "$crit" ]; then
        printf '%s' "$RED"
    elif [ "$value" -ge "$warn" ]; then
        printf '%s' "$YELLOW"
    else
        printf '%s' "$GREEN"
    fi
}

bar() {
    local value="$1"
    local width="$2"
    local color="$3"
    local filled
    local empty

    [[ "$value" =~ ^[0-9]+$ ]] || value=0
    [ "$value" -lt 0 ] && value=0
    [ "$value" -gt 100 ] && value=100

    filled=$((value * width / 100))
    empty=$((width - filled))

    printf '['
    colorize "$color" "$(repeat_char "#" "$filled")"
    repeat_char "-" "$empty"
    printf ']'
}

read_cpu_times() {
    local line name user nice system idle iowait irq softirq steal total

    CPU_TOTAL=0 CPU_IDLE=0
    CPU_CORE_TOTALS=()
    CPU_CORE_IDLES=()
    while IFS= read -r line; do
        read -r name user nice system idle iowait irq softirq steal _ <<< "$line"
        [[ "$name" == cpu* ]] || break
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        if [ "$name" = cpu ]; then
            CPU_IDLE=$((idle + iowait))
            CPU_TOTAL=$total
        elif [[ "$name" =~ ^cpu[0-9]+$ ]]; then
            CPU_CORE_TOTALS+=("$total")
            CPU_CORE_IDLES+=("$((idle + iowait))")
        fi
    done < /proc/stat
}

init_cpu_sample() {
    read_cpu_times
    PREV_CPU_IDLE=$CPU_IDLE
    PREV_CPU_TOTAL=$CPU_TOTAL
    PREV_CORE_TOTALS=("${CPU_CORE_TOTALS[@]}")
    PREV_CORE_IDLES=("${CPU_CORE_IDLES[@]}")
}

get_cpu_usage() {
    local diff_idle
    local diff_total
    local index core_total core_idle core_diff core_idle_diff
    local usage=0

    local previous_total=$PREV_CPU_TOTAL
    read_cpu_times
    diff_idle=$((CPU_IDLE - PREV_CPU_IDLE))
    diff_total=$((CPU_TOTAL - PREV_CPU_TOTAL))
    CPU_DIFF_TOTAL=$diff_total

    CPU_SAMPLE_STATE=warming
    if [ "$CPU_TOTAL" -eq 0 ]; then CPU_SAMPLE_STATE=unavailable; fi
    if [ "$diff_total" -gt 0 ] && [ "$previous_total" -gt 0 ] && [ "$diff_idle" -ge 0 ] && [ "$diff_idle" -le "$diff_total" ]; then
        CPU_SAMPLE_STATE=valid
        usage=$((100 * (diff_total - diff_idle) / diff_total))
    fi

    PREV_CPU_IDLE=$CPU_IDLE
    PREV_CPU_TOTAL=$CPU_TOTAL
    METRIC_CPU=$usage
    METRIC_CORE_CPUS=()
    for ((index = 0; index < ${#CPU_CORE_TOTALS[@]}; index++)); do
        core_total=${CPU_CORE_TOTALS[$index]}
        core_idle=${CPU_CORE_IDLES[$index]}
        core_diff=$((core_total - ${PREV_CORE_TOTALS[$index]:-$core_total}))
        core_idle_diff=$((core_idle - ${PREV_CORE_IDLES[$index]:-$core_idle}))
        if [ "$core_diff" -gt 0 ]; then
            METRIC_CORE_CPUS+=("$((100 * (core_diff - core_idle_diff) / core_diff))")
        else
            METRIC_CORE_CPUS+=(0)
        fi
    done
    PREV_CORE_TOTALS=("${CPU_CORE_TOTALS[@]}")
    PREV_CORE_IDLES=("${CPU_CORE_IDLES[@]}")
    printf '%s' "$usage"
}

read_network_counters() {
    local interface="$1" line name rx tx

    while IFS= read -r line; do
        name=${line%%:*}
        name=${name//[[:space:]]/}
        read -r rx _ _ _ _ _ _ _ _ tx _ <<< "${line#*:}"
        if [ "$name" = "$interface" ] && [[ "$rx" =~ ^[0-9]+$ && "$tx" =~ ^[0-9]+$ ]]; then
            printf '%s %s\n' "$rx" "$tx"
            return 0
        fi
    done < /proc/net/dev
    return 1
}

format_network_rate() {
    local bytes="$1" scale=1 unit=0 scaled
    local -a units=(B/s KiB/s MiB/s GiB/s)

    while [ "$bytes" -ge $((scale * 1024)) ] && [ "$unit" -lt 3 ]; do
        scale=$((scale * 1024))
        unit=$((unit + 1))
    done
    if [ "$unit" -eq 0 ]; then
        printf '%s%s' "$bytes" "${units[$unit]}"
    else
        scaled=$((bytes * 10 / scale))
        printf '%d.%d%s' "$((scaled / 10))" "$((scaled % 10))" "${units[$unit]}"
    fi
}

collect_network_metrics() {
    local now rx tx elapsed interface

    interface="$NETWORK_INTERFACE"
    if [ -z "$interface" ]; then
        interface="$METRIC_DEFAULT_IFACE"
        [ -n "$interface" ] || interface="${METRIC_INTERFACES[0]%% *}"
        interface=${interface%%@*}
    fi
    METRIC_NET_INTERFACE="$interface"
    sample_set rx "" unavailable; sample_set tx "" unavailable
    METRIC_NET_RX_RATE=N/A
    METRIC_NET_TX_RATE=N/A
    if [ -z "$interface" ] || ! read -r rx tx < <(read_network_counters "$interface"); then
        PREV_NET_INTERFACE=""
        return
    fi

    now=$SAMPLE_TIME_MS
    [ "$now" -gt 0 ] || { read_sample_clock; now=$CLOCK_MS; }
    elapsed=$((now - PREV_NET_TIME))
    sample_set rx "" warming; sample_set tx "" warming
    if [ "$interface" = "$PREV_NET_INTERFACE" ] && [ "$elapsed" -gt 0 ] &&
        [ "$rx" -ge "$PREV_NET_RX" ] && [ "$tx" -ge "$PREV_NET_TX" ]; then
        sample_set rx "$(((rx - PREV_NET_RX) * 1000 / elapsed))"
        sample_set tx "$(((tx - PREV_NET_TX) * 1000 / elapsed))"
        METRIC_NET_RX_RATE=$(format_network_rate "${SAMPLE_VALUE[rx]}")
        METRIC_NET_TX_RATE=$(format_network_rate "${SAMPLE_VALUE[tx]}")
    fi
    PREV_NET_INTERFACE=$interface
    PREV_NET_RX=$rx
    PREV_NET_TX=$tx
    PREV_NET_TIME=$now
}

read_battery_metrics() {
    local battery type capacity status

    for battery in /sys/class/power_supply/BAT*; do
        [ -d "$battery" ] || continue
        IFS= read -r type < "$battery/type" 2>/dev/null || continue
        [ "$type" = Battery ] || continue
        IFS= read -r capacity < "$battery/capacity" 2>/dev/null || continue
        [[ "$capacity" =~ ^[0-9]{1,3}$ ]] || continue
        [ "$capacity" -le 100 ] || continue
        IFS= read -r status < "$battery/status" 2>/dev/null || status=Unknown
        printf '%s%% %s' "$capacity" "${status,,}"
        return
    done
    return 0
}

collect_live_processes() {
    local pid ticks start user state elapsed rss threads parent avg mem name percent delta identity
    local LC_ALL=C
    local -A current_ticks=() current_start=()
    PROC_NAME=() PROC_CPU=() PROC_MEM=() PROC_DETAILS=()
    while read -r pid ticks start; do
        [[ "$pid $ticks $start" =~ ^[0-9]+\ [0-9]+\ [0-9]+$ ]] || continue
        current_ticks[$pid]=$ticks; current_start[$pid]=$start
    done < <(read_process_ticks)
    while read -r pid user state elapsed rss threads parent avg mem name; do
        [[ "$pid $avg $mem" =~ ^[0-9]+\ [0-9.]+\ [0-9.]+$ ]] || continue
        [ "$pid" != "$$" ] || continue
        start=${current_start[$pid]:-0}; identity=$pid:$start
        percent=$avg
        if [ "$LIVE_MODE" -eq 1 ]; then
            percent=N/A
            if [ "$CPU_DIFF_TOTAL" -gt 0 ] && [ -n "${current_ticks[$pid]+set}" ] &&
                [ "${PREV_PROC_START[$pid]:-none}" = "$start" ]; then
                delta=$((${current_ticks[$pid]} - ${PREV_PROC_TICKS[$pid]:-${current_ticks[$pid]}}))
                if [ "$delta" -ge 0 ]; then
                    percent=$((delta * CPU_COUNT * 1000 / CPU_DIFF_TOTAL))
                    printf -v percent '%d.%d' "$((percent / 10))" "$((percent % 10))"
                fi
            fi
        fi
        PROC_NAME[$identity]=${name//[![:print:]]/?}
        PROC_CPU[$identity]=$percent PROC_MEM[$identity]=$mem
        PROC_DETAILS[$identity]="User $user | State $state | Age ${elapsed}s | RSS ${rss}KiB | Threads $threads | PPID $parent"
    done < <(LC_ALL=C ps -eo pid=,user=,stat=,etimes=,rss=,nlwp=,ppid=,%cpu=,%mem=,comm= 2>/dev/null)
    PREV_PROC_TICKS=(); PREV_PROC_START=()
    for pid in "${!current_ticks[@]}"; do
        PREV_PROC_TICKS[$pid]=${current_ticks[$pid]}; PREV_PROC_START[$pid]=${current_start[$pid]}
    done
    METRIC_PROCESS_CPU_MODE=avg
    [ "$LIVE_MODE" -eq 0 ] || METRIC_PROCESS_CPU_MODE=now
    sort_processes
    collect_process_detail
}

read_process_ticks() {
    local path pid line rest
    local -a fields
    for path in /proc/[0-9]*/stat; do
        [ -r "$path" ] || continue
        pid=${path#/proc/}; pid=${pid%/stat}
        [ "$pid" = "$$" ] && continue
        IFS= read -r line 2>/dev/null < "$path" || continue
        rest=${line##*) }; read -r -a fields <<< "$rest"
        [ "${#fields[@]}" -ge 20 ] || continue
        [[ "${fields[11]} ${fields[12]} ${fields[19]}" =~ ^[0-9]+\ [0-9]+\ [0-9]+$ ]] || continue
        printf '%s %s %s\n' "$pid" "$((fields[11] + fields[12]))" "${fields[19]}"
    done
}

collect_metrics() {
    local cores load_five load_fifteen line first second third fourth fifth
    local route_interface route_gateway
    local normalized_interface

    # CPU counters must advance in the parent shell, not a command substitution.
    get_cpu_usage >/dev/null

    local memory_total memory_used swap_total swap_used
    read -r memory_total memory_used swap_total swap_used < <(
        LC_ALL=C free -b | awk '/^Mem:/ {m=$2 " " $3} /^Swap:/ {s=$2 " " $3} END {print (m ? m : "- -"), (s ? s : "- -")}'
    )
    METRIC_MEM_USED=N/A METRIC_MEM_TOTAL=N/A METRIC_MEM_PERCENT=0
    METRIC_SWAP_USED=N/A METRIC_SWAP_TOTAL=N/A METRIC_SWAP_PERCENT=0
    local key
    for key in ram memory_used_bytes memory_total_bytes swap swap_used_bytes swap_total_bytes; do sample_set "$key" "" unavailable; done
    if [[ "$memory_total $memory_used" =~ ^[0-9]+\ [0-9]+$ ]] && [ "$memory_total" -gt 0 ]; then
        METRIC_MEM_USED=$(format_bytes "$memory_used"); METRIC_MEM_TOTAL=$(format_bytes "$memory_total")
        METRIC_MEM_PERCENT=$((memory_used * 100 / memory_total))
        sample_set ram "$METRIC_MEM_PERCENT"
        sample_set memory_used_bytes "$memory_used"; sample_set memory_total_bytes "$memory_total"
    fi
    if [[ "$swap_total $swap_used" =~ ^[0-9]+\ [0-9]+$ ]]; then
        METRIC_SWAP_USED=$(format_bytes "$swap_used"); METRIC_SWAP_TOTAL=$(format_bytes "$swap_total")
        [ "$swap_total" -eq 0 ] || METRIC_SWAP_PERCENT=$((swap_used * 100 / swap_total))
        sample_set swap "$METRIC_SWAP_PERCENT"
        sample_set swap_used_bytes "$swap_used"; sample_set swap_total_bytes "$swap_total"
    fi
    sample_set cpu "" "$CPU_SAMPLE_STATE"
    if [ "$CPU_SAMPLE_STATE" = valid ]; then sample_set cpu "$METRIC_CPU"; fi
    collect_storage
    collect_device
    collect_pressure

    METRIC_LOAD_ONE=""
    read -r METRIC_LOAD_ONE load_five load_fifteen _ < /proc/loadavg
    METRIC_LOAD="$METRIC_LOAD_ONE $load_five $load_fifteen"
    cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')
    [[ "$cores" =~ ^[0-9]+$ ]] || cores=1
    [ "$cores" -lt 1 ] && cores=1
    CPU_COUNT=$cores
    sample_set load "" unavailable
    METRIC_LOAD_PERCENT=0
    if [[ "$METRIC_LOAD_ONE" =~ ^[0-9]+[.][0-9]+$ ]]; then
        METRIC_LOAD_PERCENT=$(awk -v load_one="$METRIC_LOAD_ONE" -v cores="$cores" 'BEGIN {printf "%d", load_one * 100 / cores}')
        sample_set load "$METRIC_LOAD_PERCENT"
    fi

    METRIC_TEMP=$(get_temperature)
    METRIC_TEMP_PERCENT=$(temperature_number "$METRIC_TEMP")
    sample_set temp "" unavailable
    if [[ "$METRIC_TEMP" =~ [0-9]+ ]]; then sample_set temp "$METRIC_TEMP_PERCENT"; fi
    METRIC_TEMP_SHORT=$METRIC_TEMP
    [ "$METRIC_TEMP" = "Not available" ] && METRIC_TEMP_SHORT="N/A"

    collect_live_processes

    METRIC_INTERFACES=()
    METRIC_ALL_INTERFACES=()
    METRIC_INTERFACE="No active IPv4"
    METRIC_GATEWAY=""
    METRIC_DEFAULT_IFACE=""
    while read -r first second third fourth fifth _; do
        if [ "$first" = default ]; then
            case "$second" in
                via) route_interface=$fifth; route_gateway="$third via $fifth" ;;
                dev) route_interface=$third; route_gateway="dev $third" ;;
                *) continue ;;
            esac
            if [ -z "$METRIC_GATEWAY" ] &&
                { [ -z "$NETWORK_INTERFACE" ] || [ "$route_interface" = "$NETWORK_INTERFACE" ]; }; then
                METRIC_GATEWAY=$route_gateway
                METRIC_DEFAULT_IFACE=$route_interface
            fi
        elif [[ "$first" =~ ^[0-9]+:$ ]]; then
            normalized_interface=${second%%@*}
            if [ "${#METRIC_ALL_INTERFACES[@]}" -lt 16 ]; then
                METRIC_ALL_INTERFACES+=("$second $fourth")
            fi
            if { [ -z "$NETWORK_INTERFACE" ] || [ "$normalized_interface" = "$NETWORK_INTERFACE" ]; } &&
                [ "${#METRIC_INTERFACES[@]}" -lt 4 ]; then
                [ "${#METRIC_INTERFACES[@]}" -eq 0 ] && METRIC_INTERFACE="$second $fourth"
                METRIC_INTERFACES+=("$second  $fourth")
            fi
        fi
    done < <(ip -o -4 -batch - 2>/dev/null <<< $'address show up scope global\nroute show default')

    collect_network_metrics
    METRIC_BATTERY=$(read_battery_metrics) || METRIC_BATTERY=""

    METRIC_UPTIME=$(uptime -p)
    METRIC_HOST=$(hostname)
    METRIC_USER=$(whoami)
    METRIC_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
}

get_temperature() {
    local value
    local temp

    if command -v sensors >/dev/null 2>&1; then
        value=$(sensors 2>/dev/null | grep -E -m1 'Package id 0|Core 0|temp1' | grep -Eo -m1 '[+-]?[0-9]+(\.[0-9]+)?°?C')
        if [ -n "$value" ]; then
            printf '%s' "$value"
            return
        fi
    fi

    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        printf '%sC' "$((temp / 1000))"
    else
        printf 'Not available'
    fi
}

temperature_number() {
    local temp="$1"
    if [[ "$temp" =~ ([0-9]+)([.][0-9]+)? ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else printf '0'; fi
}

metric_line() {
    local label="$1"
    local value="$2"
    local percent="$3"
    local warn="$4"
    local crit="$5"
    local color

    color=$(status_color "$percent" "$warn" "$crit")
    printf '%-11s %s %s' "$label" "$(bar "$percent" 14 "$color")" "$(colorize "$color" "$value")"
}

compact_metric() {
    local label="$1"
    local value="$2"
    local percent="$3"
    local warn="$4"
    local crit="$5"
    local bar_width="$6"
    local color

    color=$(status_color "$percent" "$warn" "$crit")
    printf '%s %s %s' "$label" "$(bar "$percent" "$bar_width" "$color")" "$(colorize "$color" "$value")"
}

print_fit_line() {
    local width="$1"
    local text="$2"

    pad_ansi "$text" "$width"
    printf '\n'
}

panel() {
    local width="$1"
    local title="$2"
    shift 2

    local inner=$((width - 4))
    local border_width=$((width - 2))
    local line

    [ "$inner" -lt 1 ] && inner=1
    [ "$border_width" -lt 1 ] && border_width=1

    printf '+%s+\n' "$(repeat_char "-" "$border_width")"
    printf '| %s |\n' "$(pad_ansi "${BOLD}${BLUE}${title}${RESET}" "$inner")"
    printf '|%s|\n' "$(repeat_char "-" "$border_width")"

    for line in "$@"; do
        printf '| %s |\n' "$(pad_ansi "$line" "$inner")"
    done

    printf '+%s+\n' "$(repeat_char "-" "$border_width")"
}

pause_label() {
    local key
    if [ -n "$RECORD_ERROR" ]; then printf ' [REC!]'; else
        for key in "${!ALERT_ACTIVE[@]}"; do
            if [ "${ALERT_ACTIVE[$key]}" -gt 0 ]; then printf ' [!]'; break; fi
        done
    fi
    [ "$PAUSED" -eq 1 ] && printf ' | PAUSED'
    return 0
}

blank_line() {
    printf '%*s' "$1" ''
}

system_panel() {
    local width="$1"
    local index core_color
    local -a rows

    rows+=("$(metric_line "CPU" "${METRIC_CPU}%" "$METRIC_CPU" "$CPU_WARN" "$CPU_CRIT")")
    rows+=("$(metric_line "RAM" "${METRIC_MEM_USED}/${METRIC_MEM_TOTAL} ${METRIC_MEM_PERCENT}%" "$METRIC_MEM_PERCENT" "$RAM_WARN" "$RAM_CRIT")")
    rows+=("$(metric_line "Disk" "${METRIC_DISK_USED}/${METRIC_DISK_TOTAL} ${METRIC_DISK_PERCENT}%" "$METRIC_DISK_PERCENT" "$DISK_WARN" "$DISK_CRIT")")
    rows+=("$(metric_line "Temp" "$METRIC_TEMP" "$METRIC_TEMP_PERCENT" "$TEMP_WARN" "$TEMP_CRIT")")
    for ((index = 0; index < ${#METRIC_CORE_CPUS[@]}; index++)); do
        core_color=$(status_color "${METRIC_CORE_CPUS[$index]}" "$CPU_WARN" "$CPU_CRIT")
        rows+=("Core $index $(bar "${METRIC_CORE_CPUS[$index]}" 8 "$core_color") ${METRIC_CORE_CPUS[$index]}%")
    done
    [ -n "$METRIC_BATTERY" ] && rows+=("Battery   $METRIC_BATTERY")
    rows+=("")
    rows+=("Uptime     $METRIC_UPTIME")

    panel "$width" "System Usage" "${rows[@]}"
}

network_panel() {
    local width="$1"
    local line
    local -a rows

    rows+=("Interfaces")
    if [ "${#METRIC_INTERFACES[@]}" -eq 0 ]; then
        rows+=("  No active IPv4 interface")
    else
        for line in "${METRIC_INTERFACES[@]}"; do
            rows+=("  $line")
        done
    fi

    rows+=("")
    rows+=("Gateway")
    rows+=("  ${METRIC_GATEWAY:-Not available}")
    rows+=("")
    rows+=("${METRIC_NET_INTERFACE:-Network} RX $METRIC_NET_RX_RATE  TX $METRIC_NET_TX_RATE")

    panel "$width" "Network" "${rows[@]}"
}

process_panel() {
    local width="$1"
    local limit="$2"
    local inner=$((width - 4))
    local name_width=$((inner - 26))
    local line
    local cpu_header=CPU
    local mem_header=MEM
    local -a rows

    [ "$name_width" -lt 8 ] && name_width=8
    [ "$name_width" -gt 28 ] && name_width=28

    [ "$PROCESS_SORT" = cpu ] && cpu_header='CPU*' || mem_header='MEM*'
    rows+=("PID    COMMAND$(repeat_char " " "$((name_width - 7))")     $cpu_header${METRIC_PROCESS_CPU_MODE:+ }${METRIC_PROCESS_CPU_MODE^^}    $mem_header")

    while IFS= read -r line; do
        rows+=("$line")
    done < <(format_process_rows "$name_width" "$limit" 6)

    if [ "${#rows[@]}" -eq 1 ]; then
        rows+=("No process data available")
    fi

    panel "$width" "Top Processes ($PROCESS_SORT sort)" "${rows[@]}"
}

render_header() {
    local width="$1"
    local title
    local status

    title="${BOLD}${CYAN}PC COMMAND CENTER$(pause_label)${RESET}"
    status="$METRIC_USER@$METRIC_HOST | $METRIC_TIME | $METRIC_UPTIME | every ${REFRESH_INTERVAL}s"

    printf '%s\n' "$(center_ansi "$title" "$width")"
    printf '%s\n' "$(pad_ansi "$status" "$width")"
    printf '%s\n' "$(repeat_char "-" "$width")"
}

render_compact_header() {
    local width="$1"
    local host
    local title
    local status

    host="$METRIC_USER@$METRIC_HOST"
    title="${BOLD}${CYAN}PC COMMAND CENTER$(pause_label)${RESET}"
    status="${METRIC_TIME#* } | $METRIC_UPTIME | every ${REFRESH_INTERVAL}s"

    print_fit_line "$width" "$title | $host | ${REFRESH_INTERVAL}s"
    print_fit_line "$width" "$status"
    printf '%s\n' "$(repeat_char "-" "$width")"
}

compact_system_rows() {
    local width="$1"
    local bar_width="$2"
    local left
    local right
    local half

    half=$(((width - 2) / 2))
    left="$(compact_metric "CPU" "${METRIC_CPU}%" "$METRIC_CPU" "$CPU_WARN" "$CPU_CRIT" "$bar_width")"
    right="$(compact_metric "RAM" "${METRIC_MEM_USED}/${METRIC_MEM_TOTAL} ${METRIC_MEM_PERCENT}%" "$METRIC_MEM_PERCENT" "$RAM_WARN" "$RAM_CRIT" "$bar_width")"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"

    left="$(compact_metric "DSK" "${METRIC_DISK_USED}/${METRIC_DISK_TOTAL} ${METRIC_DISK_PERCENT}%" "$METRIC_DISK_PERCENT" "$DISK_WARN" "$DISK_CRIT" "$bar_width")"
    right="$(compact_metric "TMP" "$METRIC_TEMP_SHORT" "$METRIC_TEMP_PERCENT" "$TEMP_WARN" "$TEMP_CRIT" "$bar_width")"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"
}

compact_health_rows() {
    local width="$1"
    local load_color
    local swap_color
    local left
    local right
    local half

    load_color=$(status_color "$METRIC_LOAD_PERCENT" "$LOAD_WARN" "$LOAD_CRIT")
    swap_color=$(status_color "$METRIC_SWAP_PERCENT" "$SWAP_WARN" "$SWAP_CRIT")

    half=$(((width - 2) / 2))
    left="LOAD $(colorize "$load_color" "$METRIC_LOAD")"
    right="PROC ${METRIC_PROCESS_COUNT:-0}"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"

    left="SWAP $(colorize "$swap_color" "${METRIC_SWAP_USED}/${METRIC_SWAP_TOTAL} ${METRIC_SWAP_PERCENT}%")"
    right="$METRIC_DISK_LABEL ${METRIC_DISK_AVAILABLE:-N/A} free"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"
}

compact_network_rows() {
    local width="$1"
    local row_limit="$2"

    if [ "$row_limit" -le 1 ]; then
        print_fit_line "$width" "${BLUE}NET${RESET} $METRIC_INTERFACE RX $METRIC_NET_RX_RATE TX $METRIC_NET_TX_RATE | GW ${METRIC_GATEWAY:-N/A}"
    else
        print_fit_line "$width" "${BLUE}NET${RESET} $METRIC_INTERFACE RX $METRIC_NET_RX_RATE TX $METRIC_NET_TX_RATE"
        print_fit_line "$width" "${BLUE}GW ${RESET} ${METRIC_GATEWAY:-N/A}"
    fi
}

compact_process_rows() {
    local width="$1"
    local limit="$2"
    local name_width=$((width - 25))
    local line
    local cpu_header=CPU
    local mem_header=MEM

    [ "$name_width" -lt 10 ] && name_width=10
    [ "$name_width" -gt 30 ] && name_width=30

    print_fit_line "$width" "${BLUE}TOP${RESET}"
    [ "$PROCESS_SORT" = cpu ] && cpu_header='CPU*' || mem_header='MEM*'
    print_fit_line "$width" "PID    COMMAND$(repeat_char " " "$((name_width - 7))")    $cpu_header${METRIC_PROCESS_CPU_MODE:+ }${METRIC_PROCESS_CPU_MODE^^}   $mem_header"

    while IFS= read -r line; do
        print_fit_line "$width" "$line"
    done < <(format_process_rows "$name_width" "$limit" 5)
}

format_process_rows() {
    local name_width="$1" limit="$2" percent_width="$3"

    awk -v nw="$name_width" -v limit="$limit" -v pw="$percent_width" '
        NF >= 4 && count < limit {
            name = $2
            for (i = 3; i <= NF - 2; i++) name = name " " $i
            if (length(name) > nw) name = substr(name, 1, nw - 1) "~"
            printf "%5s  %-*s %*s %*s\n", $1, nw, name, pw, ($(NF - 1) == "N/A" ? "N/A" : $(NF - 1) "%"), pw, $NF "%"
            count++
        }
    ' <<< "$METRIC_PROCESSES"
}

top_process_summary() {
    local name_width="$1"
    local metric_index=3

    [ "$name_width" -lt 6 ] && name_width=6
    [ "$PROCESS_SORT" = mem ] && metric_index=4
    awk -v nw="$name_width" -v metric_index="$metric_index" '
        NF >= 4 {
            name = $2
            for (i = 3; i <= NF - 2; i++) name = name " " $i
            if (length(name) > nw) name = substr(name, 1, nw - 1) "~"
            value = $(metric_index == 4 ? NF : NF - 1)
            printf "%s %s", name, (value == "N/A" ? "N/A" : value "%")
            found = 1
            exit
        }
        END { if (!found) printf "N/A" }
    ' <<< "$METRIC_PROCESSES"
}

render_mini_dashboard() {
    local cols="$1"
    local lines="$2"
    local width="$cols"
    local half
    local left
    local right
    local cpu_color
    local mem_color
    local disk_color
    local temp_color
    local swap_color

    [ "$width" -gt 59 ] && width=59
    [ "$width" -lt 1 ] && width=1
    half=$(((width - 2) / 2))
    [ "$half" -lt 1 ] && half=1

    cpu_color=$(status_color "$METRIC_CPU" "$CPU_WARN" "$CPU_CRIT")
    mem_color=$(status_color "$METRIC_MEM_PERCENT" "$RAM_WARN" "$RAM_CRIT")
    disk_color=$(status_color "$METRIC_DISK_PERCENT" "$DISK_WARN" "$DISK_CRIT")
    temp_color=$(status_color "$METRIC_TEMP_PERCENT" "$TEMP_WARN" "$TEMP_CRIT")
    swap_color=$(status_color "$METRIC_SWAP_PERCENT" "$SWAP_WARN" "$SWAP_CRIT")

    print_fit_line "$width" "${BOLD}${CYAN}PCC MINI$(pause_label)${RESET} | $METRIC_HOST | ${REFRESH_INTERVAL}s"
    print_fit_line "$width" "${METRIC_TIME#* } | $METRIC_UPTIME"
    printf '%s\n' "$(repeat_char "-" "$width")"

    left="CPU $(bar "$METRIC_CPU" 5 "$cpu_color") $(colorize "$cpu_color" "${METRIC_CPU}%")"
    right="RAM $(bar "$METRIC_MEM_PERCENT" 5 "$mem_color") $(colorize "$mem_color" "${METRIC_MEM_PERCENT}%")"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"

    left="DSK $(colorize "$disk_color" "${METRIC_DISK_PERCENT}%")"
    right="TMP $(colorize "$temp_color" "$METRIC_TEMP_SHORT")"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"

    left="LOAD $METRIC_LOAD"
    right="PROC ${METRIC_PROCESS_COUNT:-0}"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"

    left="SWAP $(colorize "$swap_color" "${METRIC_SWAP_PERCENT}%")"
    right="$METRIC_DISK_LABEL ${METRIC_DISK_AVAILABLE:-N/A}"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"

    if [ "$lines" -ge 12 ]; then
        print_fit_line "$width" "TOP ${PROCESS_SORT^^} $(top_process_summary "$((width - 20))")"
    fi

    printf '%s\n' "$(repeat_char "-" "$width")"
    print_fit_line "$width" "q/r +/- c/m p ? n"
}

render_micro_dashboard() {
    local cols="$1"
    local lines="$2"
    local width="$cols"
    local cpu_color
    local mem_color
    local disk_color
    local temp_color

    [ "$width" -gt 44 ] && width=44
    [ "$width" -lt 1 ] && width=1

    cpu_color=$(status_color "$METRIC_CPU" "$CPU_WARN" "$CPU_CRIT")
    mem_color=$(status_color "$METRIC_MEM_PERCENT" "$RAM_WARN" "$RAM_CRIT")
    disk_color=$(status_color "$METRIC_DISK_PERCENT" "$DISK_WARN" "$DISK_CRIT")
    temp_color=$(status_color "$METRIC_TEMP_PERCENT" "$TEMP_WARN" "$TEMP_CRIT")

    print_fit_line "$width" "${BOLD}${CYAN}PCC MICRO$(pause_label)${RESET} | ${REFRESH_INTERVAL}s"
    printf '%s\n' "$(repeat_char "-" "$width")"
    print_fit_line "$width" "CPU $(colorize "$cpu_color" "${METRIC_CPU}%") | RAM $(colorize "$mem_color" "${METRIC_MEM_PERCENT}%")"
    print_fit_line "$width" "DSK $(colorize "$disk_color" "${METRIC_DISK_PERCENT}%") | TMP $(colorize "$temp_color" "$METRIC_TEMP_SHORT")"
    print_fit_line "$width" "LOAD $METRIC_LOAD_ONE | SWAP ${METRIC_SWAP_PERCENT}%"
    [ "$lines" -ge 10 ] && print_fit_line "$width" "$METRIC_DISK_LABEL ${METRIC_DISK_AVAILABLE:-N/A} free"
    printf '%s\n' "$(repeat_char "-" "$width")"
    print_fit_line "$width" "q/r +/- c/m p ? n"
}

render_tiny_fallback() {
    local cols="$1"
    local width="$cols"

    [ "$width" -lt 1 ] && width=1

    print_fit_line "$width" "${BOLD}${CYAN}PCC$(pause_label)${RESET} ${REFRESH_INTERVAL}s"
    print_fit_line "$width" "CPU ${METRIC_CPU}% RAM ${METRIC_MEM_PERCENT}%"
    print_fit_line "$width" "DSK ${METRIC_DISK_PERCENT}%"
    print_fit_line "$width" "q/r +/- c/m p ? n"
}

render_compact_dashboard() {
    local cols="$1"
    local lines="$2"
    local width="$cols"
    local process_limit=4
    local network_rows=2
    local bar_width=9

    [ "$width" -gt 88 ] && width=88
    [ "$width" -lt 60 ] && width=60

    if [ "$lines" -lt 24 ]; then
        process_limit=3
        network_rows=1
    fi

    if [ "$lines" -lt 21 ]; then
        process_limit=2
        network_rows=1
    fi

    if [ "$width" -ge 82 ]; then
        bar_width=10
    elif [ "$width" -lt 72 ]; then
        bar_width=7
    fi

    render_compact_header "$width"
    print_fit_line "$width" "${BLUE}SYS${RESET}"
    compact_system_rows "$width" "$bar_width"
    printf '%s\n' "$(repeat_char "-" "$width")"
    print_fit_line "$width" "${BLUE}HLT${RESET}"
    compact_health_rows "$width"
    printf '%s\n' "$(repeat_char "-" "$width")"
    compact_network_rows "$width" "$network_rows"
    printf '%s\n' "$(repeat_char "-" "$width")"
    compact_process_rows "$width" "$process_limit"
    print_fit_line "$width" "$(alert_summary)"
    print_fit_line "$width" "Controls: 1-5 views | e events | q/r +/- c/m p ? n"
}

render_wide_dashboard() {
    local width=$TERM_COLS line index cores=""
    [ "$width" -le 120 ] || width=120
    render_header "$width"
    print_fit_line "$width" "CPU ${METRIC_CPU}% | RAM ${METRIC_MEM_PERCENT}% | Disk ${METRIC_DISK_PERCENT}% | Temp $METRIC_TEMP_SHORT"
    for ((index=0; index<${#METRIC_CORE_CPUS[@]} && index<8; index++)); do cores+=" C$index:${METRIC_CORE_CPUS[$index]}%"; done
    [ "${#METRIC_CORE_CPUS[@]}" -le 8 ] || cores+=" (+$((${#METRIC_CORE_CPUS[@]} - 8)) cores)"
    print_fit_line "$width" "Cores:$cores"
    [ -z "$METRIC_BATTERY" ] || print_fit_line "$width" "Battery: $METRIC_BATTERY"
    print_fit_line "$width" "Load $METRIC_LOAD | Swap ${METRIC_SWAP_PERCENT}% | $METRIC_DISK_LABEL ${METRIC_DISK_AVAILABLE:-N/A} free"
    print_fit_line "$width" "${METRIC_NET_INTERFACE:-Network} RX $METRIC_NET_RX_RATE TX $METRIC_NET_TX_RATE | GW ${METRIC_GATEWAY:-N/A}"
    while IFS= read -r line; do print_fit_line "$width" "$line"; done < <(history_rows "$width")
    print_fit_line "$width" "Top Processes (${METRIC_PROCESS_CPU_MODE^^}) | CPU 100%=one core"
    while IFS= read -r line; do print_fit_line "$width" "$line"; done < <(format_process_rows 28 3 6)
    print_fit_line "$width" "$(alert_summary)"
    print_fit_line "$width" '1 overview 2 proc 3 disk 4 net 5 pressure | e events | ? help'
}

read_dimensions() {
    RESIZE_PENDING=0
    TERM_COLS=$(tput_cmd cols)
    TERM_LINES=$(tput_cmd lines)
    [[ "$TERM_COLS" =~ ^[1-9][0-9]{0,5}$ ]] || TERM_COLS=${COLUMNS:-80}
    [[ "$TERM_LINES" =~ ^[1-9][0-9]{0,5}$ ]] || TERM_LINES=${LINES:-24}
    [[ "$TERM_COLS" =~ ^[1-9][0-9]{0,5}$ ]] || TERM_COLS=80
    [[ "$TERM_LINES" =~ ^[1-9][0-9]{0,5}$ ]] || TERM_LINES=24
}

render_dashboard() {
    if [ "$LIVE_MODE" -eq 0 ] || [ "$RESIZE_PENDING" -eq 1 ]; then
        read_dimensions
    fi
    local cols=$TERM_COLS lines=$TERM_LINES layout=$LAYOUT

    if [ "$LIVE_MODE" -eq 1 ]; then
        tput_cmd cup 0 0
    fi

    if [ "$layout" = auto ]; then
        if [ "$cols" -ge 60 ] && [ "$lines" -ge 20 ]; then
            layout=compact
        elif [ "$cols" -ge 45 ] && [ "$lines" -ge 12 ]; then
            layout=mini
        elif [ "$cols" -ge 36 ] && [ "$lines" -ge 8 ]; then
            layout=micro
        else
            layout=tiny
        fi
    fi
    if [ "$VIEW" != overview ] || [ "$EVENTS_VISIBLE" -eq 1 ]; then
        render_focused_view
        [ "$LIVE_MODE" -eq 0 ] || tput_cmd ed
        return 0
    fi
    local -a frame=()
    local row limit=$TERM_LINES
    mapfile -t frame < <(case "$layout" in
        wide) render_wide_dashboard ;;
        compact) render_compact_dashboard "$cols" "$lines" ;;
        mini) render_mini_dashboard "$cols" "$lines" ;;
        micro) render_micro_dashboard "$cols" "$lines" ;;
        tiny) render_tiny_fallback "$cols" ;;
    esac)
    for ((row=0; row<${#frame[@]} && row<limit; row++)); do
        printf '%s\n' "${frame[$row]}"
    done
    if [ "$LIVE_MODE" -eq 1 ]; then
        tput_cmd ed
    fi
}

render_help_overlay() {
    local width="$TERM_COLS"
    local lines="$TERM_LINES"

    if [ "$LIVE_MODE" -eq 1 ] && [ "$RESIZE_PENDING" -eq 1 ]; then
        read_dimensions
        width=$TERM_COLS
        lines=$TERM_LINES
    fi
    [ "$width" -gt 120 ] && width=120
    [ "$width" -lt 1 ] && width=1
    if [ "$LIVE_MODE" -eq 1 ]; then
        tput_cmd cup 0 0
    fi
    if [ "$lines" -ge 5 ]; then
        print_fit_line "$width" "PC COMMAND CENTER HELP"
        if [ "$width" -ge 40 ]; then
            print_fit_line "$width" "q quit | r refresh | +/- speed"
            print_fit_line "$width" "c CPU | m memory | p pause/resume"
            print_fit_line "$width" "n network interface | ? help"
            print_fit_line "$width" "Any key dismisses help and redraws"
        else
            print_fit_line "$width" "q quit r refresh +/- speed"
            print_fit_line "$width" "c CPU m MEM p pause"
            print_fit_line "$width" "n network ? help"
            print_fit_line "$width" "Any key dismisses"
        fi
        [ "$lines" -ge 6 ] && print_fit_line "$width" "1 overview 2 processes 3 storage 4 network"
        [ "$lines" -ge 7 ] && print_fit_line "$width" "5 pressure | e events | j/k scroll/select"
        [ "$lines" -ge 8 ] && print_fit_line "$width" "/ filter | Enter details | Esc back | a args"
        [ "$lines" -ge 9 ] && print_fit_line "$width" "Sort: $PROCESS_SORT | Refresh: ${REFRESH_INTERVAL}s"
    elif [ "$lines" -ge 3 ]; then
        print_fit_line "$width" "q/r +/- c/m p ? n"
        print_fit_line "$width" "quit refresh sort pause"
        print_fit_line "$width" "network/help; any key hides"
    else
        print_fit_line "$width" "q/r +/- c/m p ? n"
    fi
    if [ "$LIVE_MODE" -eq 1 ]; then
        tput_cmd ed
    fi
}

cycle_network_interface() {
    local entry interface current="${NETWORK_INTERFACE:-$METRIC_NET_INTERFACE}"
    local index=-1 next
    local -a interfaces=()

    for entry in "${METRIC_ALL_INTERFACES[@]}"; do
        interface=${entry%% *}
        interface=${interface%%@*}
        case " ${interfaces[*]} " in
            *" $interface "*) ;;
            *) interfaces+=("$interface") ;;
        esac
    done
    [ "${#interfaces[@]}" -gt 1 ] || return 1
    for ((index = 0; index < ${#interfaces[@]}; index++)); do
        [ "${interfaces[$index]}" = "$current" ] && break
    done
    [ "$index" -ge "${#interfaces[@]}" ] && index=-1
    next=$(((index + 1) % ${#interfaces[@]}))
    NETWORK_INTERFACE=${interfaces[$next]}
    return 0
}

schedule_next_draw() {
    if [ "$PAUSED" -eq 1 ] || [ "$HELP_VISIBLE" -eq 1 ]; then
        NEXT_DRAW=0
    else
        NEXT_DRAW=$(( ${EPOCHSECONDS:-$SECONDS} + REFRESH_INTERVAL ))
    fi
}

handle_key() {
    local key="$1"
    if [ "$HELP_VISIBLE" -eq 1 ]; then
        HELP_VISIBLE=0 RESIZE_PENDING=1
        render_dashboard; schedule_next_draw; return 0
    fi
    if [ "$FILTER_EDITING" -eq 1 ]; then
        case "$key" in
            '') PROCESS_FILTER=$FILTER_INPUT; FILTER_EDITING=0; PROCESS_OFFSET=0; filter_processes ;;
            $'\e') FILTER_EDITING=0 ;;
            $'\177'|$'\b') FILTER_INPUT=${FILTER_INPUT%?} ;;
            *) if [[ "$key" == [[:print:]] ]] && [ "${#FILTER_INPUT}" -lt 128 ]; then FILTER_INPUT+=$key; fi ;;
        esac
        render_dashboard; return 0
    fi
    case "$key" in
        q|Q) exit "$EXIT_STATUS" ;;
        r|R) collect_sample || true; schedule_next_draw ;;
        +|=) [ "$REFRESH_INTERVAL" -le 1 ] || REFRESH_INTERVAL=$((REFRESH_INTERVAL - 1)); schedule_next_draw ;;
        -|_) [ "$REFRESH_INTERVAL" -ge 999999 ] || REFRESH_INTERVAL=$((REFRESH_INTERVAL + 1)); schedule_next_draw ;;
        c|C) PROCESS_SORT=cpu; sort_processes ;;
        m|M) PROCESS_SORT=mem; sort_processes ;;
        p|P)
            if [ "$PAUSED" -eq 0 ]; then PAUSED=1; break_sampling
            else PAUSED=0; break_sampling; collect_sample || true; fi
            schedule_next_draw ;;
        \?) HELP_VISIBLE=1; break_sampling; schedule_next_draw; render_help_overlay; return 0 ;;
        n|N)
            if ! cycle_network_interface; then return 0; fi
            PREV_NET_INTERFACE=""
            METRIC_NET_INTERFACE=$NETWORK_INTERFACE
            METRIC_NET_RX_RATE=N/A METRIC_NET_TX_RATE=N/A
            sample_set rx "" warming; sample_set tx "" warming ;;
        1) VIEW=overview; EVENTS_VISIBLE=0 ;;
        2) VIEW=processes; EVENTS_VISIBLE=0 ;;
        3) VIEW=storage; EVENTS_VISIBLE=0 ;;
        4) VIEW=network; EVENTS_VISIBLE=0 ;;
        5) VIEW=pressure; EVENTS_VISIBLE=0 ;;
        e|E) EVENTS_VISIBLE=$((1 - EVENTS_VISIBLE)); EVENT_OFFSET=0 ;;
        /) if [ "$VIEW" = processes ]; then FILTER_EDITING=1; FILTER_INPUT=$PROCESS_FILTER; fi ;;
        '') [ "$VIEW" != processes ] || PROCESS_DETAIL=1 ;;
        $'\e') PROCESS_DETAIL=0; EVENTS_VISIBLE=0 ;;
        a|A) if [ "$VIEW" = processes ] && [ "$PROCESS_DETAIL" -eq 1 ]; then SHOW_ARGUMENTS=$((1 - SHOW_ARGUMENTS)); DETAIL_ARGUMENTS=""; fi ;;
        j|k)
            local direction=1
            [ "$key" != k ] || direction=-1
            if [ "$EVENTS_VISIBLE" -eq 1 ]; then
                EVENT_OFFSET=$((EVENT_OFFSET + direction)); [ "$EVENT_OFFSET" -ge 0 ] || EVENT_OFFSET=0
                [ "$EVENT_OFFSET" -lt "$EVENT_COUNT" ] || EVENT_OFFSET=$((EVENT_COUNT > 0 ? EVENT_COUNT - 1 : 0))
            elif [ "$VIEW" = processes ]; then move_selection "$direction"
            elif [ "$VIEW" = storage ]; then
                STORAGE_OFFSET=$((STORAGE_OFFSET + direction)); [ "$STORAGE_OFFSET" -ge 0 ] || STORAGE_OFFSET=0
                [ "$STORAGE_OFFSET" -lt "${#STORAGE_IDS[@]}" ] || STORAGE_OFFSET=$((${#STORAGE_IDS[@]} > 0 ? ${#STORAGE_IDS[@]} - 1 : 0))
            fi ;;
        *) return 0 ;;
    esac
    render_dashboard
}

run_live() {
    local key now
    LIVE_MODE=1
    trap cleanup EXIT
    trap 'exit "$EXIT_STATUS"' INT TERM
    trap 'RESIZE_PENDING=1' WINCH
    setup_terminal
    collect_sample
    render_dashboard
    schedule_next_draw
    while true; do
        if read -rsn1 -t 0.1 key; then handle_key "$key"; fi
        now=${EPOCHSECONDS:-$SECONDS}
        if [ "$RESIZE_PENDING" -eq 1 ]; then
            if [ "$HELP_VISIBLE" -eq 1 ]; then render_help_overlay; else render_dashboard; fi
        fi
        if [ "$PAUSED" -eq 0 ] && [ "$HELP_VISIBLE" -eq 0 ] && [ "$now" -ge "$NEXT_DRAW" ]; then
            collect_sample
            render_dashboard
            schedule_next_draw
        fi
    done
}

# Read a boot-relative centisecond clock only at sample boundaries.
read_sample_clock() {
    local uptime_value whole fraction
    CLOCK_MS=0
    read -r uptime_value _ < /proc/uptime || return 1
    [[ "$uptime_value" =~ ^[0-9]+\.[0-9]+$ ]] || return 1
    whole=${uptime_value%.*}
    fraction=${uptime_value#*.}00
    CLOCK_MS=$((10#$whole * 1000 + 10#${fraction:0:3}))
}

sample_set() {
    SAMPLE_VALUE[$1]=$2
    SAMPLE_STATE[$1]=${3:-valid}
}

break_sampling() {
    SAMPLE_GAP=1
    BASELINE_RESET=1
    local key
    for key in "${!ALERT_PENDING[@]}"; do ALERT_PENDING[$key]=""; done
    for key in "${!ALERT_ACTIVE[@]}"; do
        if [ "${ALERT_ACTIVE[$key]}" -gt 0 ]; then ALERT_UNKNOWN[$key]=1; fi
    done
}

collect_sample() {
    local previous=$SAMPLE_TIME_MS key
    if ! read_sample_clock; then
        break_sampling
        return 1
    fi
    # Coalesce refreshes within the clock resolution; repainting is still allowed.
    [ "$SAMPLE_SEQUENCE" -gt 0 ] && [ "$CLOCK_MS" -eq "$previous" ] && return 1
    SAMPLE_TIME_MS=$CLOCK_MS
    SAMPLE_INTERVAL_MS=$((SAMPLE_TIME_MS - previous))
    if [ "$SAMPLE_SEQUENCE" -eq 0 ]; then
        SAMPLE_START_MS=$SAMPLE_TIME_MS
        SAMPLE_INTERVAL_MS=0
    elif [ "$SAMPLE_INTERVAL_MS" -lt 0 ] || [ "$SAMPLE_INTERVAL_MS" -gt "$((REFRESH_INTERVAL * 2000))" ]; then
        break_sampling
    fi
    if [ "$BASELINE_RESET" -eq 1 ]; then
        PREV_CPU_TOTAL=0 PREV_CPU_IDLE=0
        PREV_PROC_TICKS=() PREV_PROC_START=()
        PREV_NET_INTERFACE="" PREV_DEVICE=""
    fi
    SAMPLE_VALUE=() SAMPLE_STATE=()
    collect_metrics
    if [ "$BASELINE_RESET" -eq 1 ]; then
        sample_set cpu "" warming
        METRIC_CPU=N/A
        METRIC_CORE_CPUS=()
        BASELINE_RESET=0
    fi
    SAMPLE_SEQUENCE=$((SAMPLE_SEQUENCE + 1))
    SAMPLE_UTC=$METRIC_TIME
    SESSION_ID=${SESSION_ID:-${SAMPLE_UTC}-$$}
    if [ "$LIVE_MODE" -eq 1 ]; then
        append_history
        evaluate_alerts
    fi
    record_sample
    SAMPLE_GAP=0
    # Ensure an unavailable source never renders as a healthy zero.
    for key in cpu ram swap disk load temp; do
        [ "${SAMPLE_STATE[$key]:-unavailable}" = valid ] && continue
        case "$key" in
            cpu) METRIC_CPU=N/A ;;
            ram) METRIC_MEM_PERCENT=N/A ;;
            swap) METRIC_SWAP_PERCENT=N/A ;;
            disk) METRIC_DISK_PERCENT=N/A ;;
            load) METRIC_LOAD_PERCENT=N/A ;;
            temp) METRIC_TEMP_PERCENT=N/A ;;
        esac
    done
    return 0
}

append_history() {
    [ "$HISTORY_ENABLED" -eq 1 ] || return 0
    local series index=$HISTORY_HEAD i
    if [ "$HISTORY_INTERFACE" != "$METRIC_NET_INTERFACE" ]; then
        for ((i=0; i<HISTORY_SAMPLES; i++)); do
            unset 'HISTORY_VALUES[rx,'"$i"']' 'HISTORY_VALUES[tx,'"$i"']'
        done
        HISTORY_INTERFACE=$METRIC_NET_INTERFACE
    fi
    HISTORY_TIMES[index]=$SAMPLE_TIME_MS
    HISTORY_GAPS[index]=$SAMPLE_GAP
    for series in cpu ram rx tx; do
        HISTORY_VALUES[$series,$index]="?"
        if [ "${SAMPLE_STATE[$series]:-unavailable}" = valid ]; then
            HISTORY_VALUES[$series,$index]=${SAMPLE_VALUE[$series]}
        fi
    done
    HISTORY_HEAD=$(((HISTORY_HEAD + 1) % HISTORY_SAMPLES))
    [ "$HISTORY_COUNT" -ge "$HISTORY_SAMPLES" ] || HISTORY_COUNT=$((HISTORY_COUNT + 1))
}

history_graph() {
    local series=$1 width=$2 scale=${3:-100} count=$HISTORY_COUNT offset index value level
    local alphabet='._:-=+*#%@' result=""
    [ "$count" -le "$width" ] || count=$width
    [ "$scale" -gt 0 ] || scale=1
    for ((offset=count; offset>0; offset--)); do
        index=$(((HISTORY_HEAD - offset + HISTORY_SAMPLES) % HISTORY_SAMPLES))
        value=${HISTORY_VALUES[$series,$index]:-?}
        if [ "${HISTORY_GAPS[$index]:-0}" -eq 1 ]; then
            result+='|'
        elif ! [[ "$value" =~ ^[0-9]+$ ]]; then
            result+='?'
        else
            level=$((value * 9 / scale))
            [ "$level" -le 9 ] || level=9
            result+=${alphabet:$level:1}
        fi
    done
    printf '%s' "$result"
}

history_rows() {
    local width=$1 count=$HISTORY_COUNT index offset series value peak=0 span=0
    [ "$HISTORY_ENABLED" -eq 1 ] && [ "$count" -gt 0 ] || return 0
    width=$((width - 7))
    [ "$width" -gt 0 ] || return 0
    [ "$count" -le "$width" ] || count=$width
    for ((offset=count; offset>0; offset--)); do
        index=$(((HISTORY_HEAD - offset + HISTORY_SAMPLES) % HISTORY_SAMPLES))
        for series in rx tx; do
            value=${HISTORY_VALUES[$series,$index]:-?}
            [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt "$peak" ] && peak=$value
        done
    done
    index=$(((HISTORY_HEAD - count + HISTORY_SAMPLES) % HISTORY_SAMPLES))
    span=$(((SAMPLE_TIME_MS - ${HISTORY_TIMES[$index]}) / 1000))
    printf 'History: %s samples / %ss (? missing | gap)\n' "$count" "$span"
    printf 'CPU %s 0-100%%\n' "$(history_graph cpu "$width")"
    printf 'RAM %s 0-100%%\n' "$(history_graph ram "$width")"
    printf 'RX  %s\nTX  %s\n' "$(history_graph rx "$width" "$peak")" "$(history_graph tx "$width" "$peak")"
    printf 'Network peak: %s (%s)\n' "$(format_network_rate "$peak")" "${HISTORY_INTERFACE:-N/A}"
}

append_event() {
    EVENTS[EVENT_HEAD]="$SAMPLE_UTC $1"
    EVENT_HEAD=$(((EVENT_HEAD + 1) % EVENT_CAPACITY))
    [ "$EVENT_COUNT" -ge "$EVENT_CAPACITY" ] || EVENT_COUNT=$((EVENT_COUNT + 1))
    return 0
}

alert_observe() {
    local key=$1 value=$2 state=$3 warn=$4 crit=$5 margin=$6 label=$7
    local active=${ALERT_ACTIVE[$1]:-0} desired duration recovery_warn recovery_crit
    local now=$SAMPLE_TIME_MS previous=${ALERT_LAST[$1]:-0}
    if [ "$state" != valid ] || [ "$SAMPLE_GAP" -eq 1 ] ||
        { [ "$previous" -gt 0 ] && [ "$((now - previous))" -gt "$((REFRESH_INTERVAL * 2000))" ]; }; then
        ALERT_PENDING[$key]=""
        if [ "$active" -gt 0 ] && [ "${ALERT_UNKNOWN[$key]:-0}" -eq 0 ]; then
            append_event "$label observation unavailable"
        fi
        ALERT_UNKNOWN[$key]=1
        ALERT_LAST[$key]=$now
        [ "$state" = valid ] || return 0
    fi
    ALERT_LAST[$key]=$now
    [ "$active" -gt 0 ] || ALERT_UNKNOWN[$key]=0
    recovery_warn=$((warn - margin)); [ "$recovery_warn" -ge 0 ] || recovery_warn=0
    recovery_crit=$((crit - margin)); [ "$recovery_crit" -ge 0 ] || recovery_crit=0
    desired=$active
    if [ "$value" -ge "$crit" ]; then
        desired=2
    elif [ "$active" -eq 2 ]; then
        if [ "$value" -le "$recovery_crit" ]; then
            desired=1
            [ "$value" -le "$recovery_warn" ] && desired=0
        fi
    elif [ "$value" -ge "$warn" ]; then
        desired=1
    elif [ "$value" -le "$recovery_warn" ]; then
        desired=0
    fi
    if [ "$desired" -eq "$active" ] && [ "${ALERT_UNKNOWN[$key]:-0}" -eq 0 ]; then
        ALERT_PENDING[$key]=""
        return 0
    fi
    duration=$((ALERT_TRIGGER_SECONDS * 1000))
    [ "$desired" -ge "$active" ] || duration=$((ALERT_RECOVERY_SECONDS * 1000))
    if [ "${ALERT_PENDING[$key]:-}" != "$desired" ]; then
        ALERT_PENDING[$key]=$desired
        ALERT_SINCE[$key]=$now
        return 0
    fi
    [ "$((now - ${ALERT_SINCE[$key]}))" -ge "$duration" ] || return 0
    ALERT_ACTIVE[$key]=$desired
    ALERT_UNKNOWN[$key]=0
    ALERT_PENDING[$key]=""
    case "$desired" in
        0) append_event "$label cleared (latest $value)" ;;
        1) append_event "$label WARN (latest $value; confirmed $((duration / 1000))s)" ;;
        2) append_event "$label CRIT (latest $value; confirmed $((duration / 1000))s)" ;;
    esac
}

evaluate_alerts() {
    [ "$WARNINGS_ENABLED" -eq 1 ] || return 0
    local metric upper warn crit margin key label
    for metric in cpu ram disk temp load swap; do
        upper=${metric^^}; warn=${upper}_WARN; crit=${upper}_CRIT
        key=$metric label=$upper margin=$ALERT_PERCENT_MARGIN
        [ "$metric" != temp ] || margin=$ALERT_TEMP_MARGIN
        [ "$metric" != disk ] || { key="disk:$DISK_PATH"; label="Disk $DISK_PATH"; }
        alert_observe "$key" "${SAMPLE_VALUE[$metric]:-0}" "${SAMPLE_STATE[$metric]:-unavailable}" \
            "${!warn}" "${!crit}" "$margin" "$label"
    done
}

alert_summary() {
    local key severity=0 count=0 chosen="" unknown=""
    if [ -n "$RECORD_ERROR" ]; then printf 'RECORD: %s' "$RECORD_ERROR"; return; fi
    [ "$WARNINGS_ENABLED" -eq 1 ] || { printf 'Warnings off'; return; }
    for key in "${!ALERT_ACTIVE[@]}"; do
        [ "${ALERT_ACTIVE[$key]}" -gt 0 ] || continue
        count=$((count + 1))
        if [ "${ALERT_ACTIVE[$key]}" -gt "$severity" ]; then
            severity=${ALERT_ACTIVE[$key]}; chosen=$key; unknown=""
            [ "${ALERT_UNKNOWN[$key]:-0}" -eq 0 ] || unknown=' (stale)'
        fi
    done
    if [ "$count" -eq 0 ]; then
        printf 'No confirmed warnings | e events'
    else
        [ "$severity" -eq 2 ] && printf 'CRIT ' || printf 'WARN '
        printf '%s%s (%s active) | e events' "$chosen" "$unknown" "$count"
    fi
}

# Keep all external text within the ASCII width model. Percent encoding is
# reversible at the byte level, including invalid UTF-8 and terminal controls.
encode_text() {
    local LC_ALL=C text=$1 char code i
    for ((i=0; i<${#text}; i++)); do
        char=${text:i:1}
        if [[ "$char" =~ ^[a-zA-Z0-9_./:]$ ]] || { [ "$char" = - ] && [ "$i" -gt 0 ]; }; then
            printf '%s' "$char"
        else
            printf -v code '%02X' "'$char"
            printf '%%%s' "$code"
        fi
    done
}

safe_display() {
    local LC_ALL=C text=$1 char i
    for ((i=0; i<${#text}; i++)); do
        char=${text:i:1}
        if [[ "$char" == [[:print:]] ]]; then printf '%s' "$char"; else printf '?'; fi
    done
}

format_bytes() {
    local bytes=$1 unit=0 scale=1 scaled
    local -a units=(B Ki Mi Gi Ti Pi Ei)
    [[ "$bytes" =~ ^[0-9]+$ ]] || { printf 'N/A'; return; }
    while [ "$((bytes / scale))" -ge 1024 ] && [ "$unit" -lt 6 ]; do
        unit=$((unit + 1)); scale=$((scale * 1024))
    done
    scaled=$((bytes / scale))
    if [ "$unit" -gt 0 ] && [ "$scaled" -lt 10 ]; then
        printf '%s.%s%s' "$scaled" "$(((bytes % scale) * 10 / scale))" "${units[$unit]}"
    else printf '%s%s' "$scaled" "${units[$unit]}"; fi
}

read_mounts() {
    local line left right dev mount type
    MOUNT_PATHS=() MOUNT_DEVS=() MOUNT_TYPES=()
    while IFS= read -r line; do
        left=${line%% - *}; right=${line#* - }
        read -r _ _ dev _ mount _ <<< "$left"
        read -r type _ <<< "$right"
        # mountinfo escapes only space, tab, newline and backslash in paths.
        printf -v mount '%b' "$mount"
        MOUNT_PATHS+=("$mount"); MOUNT_DEVS+=("$dev"); MOUNT_TYPES+=("$type")
    done < /proc/self/mountinfo
}

collect_storage() {
    local path resolved i best length id type value index row raw label old
    local -a paths=("$DISK_PATH" "${WATCH_DISKS[@]}") query_paths=() query_ids=()
    local -a fields=() output=()
    STORAGE_IDS=() STORAGE_PATH=() STORAGE_MOUNT=() STORAGE_TYPE=() STORAGE_VALUE=() STORAGE_STATE=() STORAGE_ALIAS=()
    read_mounts
    for path in "${paths[@]}"; do
        resolved=$(CDPATH='' cd -P -- "$path" 2>/dev/null && pwd -P) || resolved=""
        best=-1 length=-1
        for ((i=0; i<${#MOUNT_PATHS[@]}; i++)); do
            value=${MOUNT_PATHS[$i]}
            if [[ "$resolved" = "$value" || "$resolved" = "$value/"* || "$value" = / ]]; then
                if [ "${#value}" -gt "$length" ]; then best=$i; length=${#value}; fi
            fi
        done
        id="path:$(encode_text "$path")" type=unknown
        if [ -n "$resolved" ] && [ "$best" -ge 0 ]; then
            id=${MOUNT_DEVS[$best]}; type=${MOUNT_TYPES[$best]}
        fi
        old=${STORAGE_EXPECT[$path]:-}
        [ -n "$old" ] || STORAGE_EXPECT[$path]=$id
        if [ -n "$old" ] && [ "$old" != "$id" ]; then id="changed:$(encode_text "$path")"; fi
        if [ -n "${STORAGE_PATH[$id]+set}" ]; then
            STORAGE_ALIAS[$id]="${STORAGE_ALIAS[$id]:-} $(safe_display "$path")"
            continue
        fi
        STORAGE_IDS+=("$id"); STORAGE_PATH[$id]=$path; STORAGE_TYPE[$id]=$type
        STORAGE_MOUNT[$id]=N/A
        [ "$best" -lt 0 ] || STORAGE_MOUNT[$id]=${MOUNT_PATHS[$best]}
        STORAGE_STATE[$id]=unavailable
        if [ -z "$resolved" ] || [ "$best" -lt 0 ] || [[ "$id" = changed:* ]]; then continue; fi
        # Explicitly skip remote/FUSE/autofs mounts; coreutils timeout bounds local probes.
        case "$type" in nfs*|cifs|smb*|fuse*|autofs|9p|ceph|afs) STORAGE_STATE[$id]=unsupported; continue ;; esac
        query_paths+=("$resolved"); query_ids+=("$id")
    done
    if [ "${#query_paths[@]}" -gt 0 ]; then
        # One query supplies both capacity and inode statistics for all selections.
        if raw=$(LC_ALL=C timeout -k 1 2 df -B1 --output=size,used,avail,pcent,itotal,iused,iavail,ipcent -- "${query_paths[@]}" 2>/dev/null); then
            mapfile -t output <<< "$raw"
            if [ "${#output[@]}" -eq "$((${#query_ids[@]} + 1))" ]; then
                for ((index=0; index<${#query_ids[@]}; index++)); do
                    id=${query_ids[$index]}; row=${output[$((index+1))]}
                    read -r -a fields <<< "$row"
                    [ "${#fields[@]}" -eq 8 ] || continue
                    for i in 0 1 2 3 4 5 6 7; do
                        value=${fields[$i]%\%}
                        [[ "$value" =~ ^[0-9]+$ ]] || value=""
                        STORAGE_VALUE[$id,$i]=$value
                    done
                    if [ -n "${STORAGE_VALUE[$id,0]}" ] && [ -n "${STORAGE_VALUE[$id,3]}" ]; then STORAGE_STATE[$id]=valid; fi
                done
            fi
        fi
    fi
    id=${STORAGE_IDS[0]:-none}
    METRIC_DISK_LABEL=ROOT; [ "$DISK_PATH" = / ] || METRIC_DISK_LABEL=DISK
    METRIC_DISK_USED=N/A METRIC_DISK_TOTAL=N/A METRIC_DISK_AVAILABLE=N/A METRIC_DISK_PERCENT=0
    sample_set disk "" "${STORAGE_STATE[$id]:-unavailable}"
    sample_set disk_used_bytes "" unavailable; sample_set disk_available_bytes "" unavailable
    if [ "${STORAGE_STATE[$id]:-unavailable}" = valid ]; then
        METRIC_DISK_USED=$(format_bytes "${STORAGE_VALUE[$id,1]}")
        METRIC_DISK_TOTAL=$(format_bytes "${STORAGE_VALUE[$id,0]}")
        METRIC_DISK_AVAILABLE=$(format_bytes "${STORAGE_VALUE[$id,2]}")
        METRIC_DISK_PERCENT=${STORAGE_VALUE[$id,3]}
        sample_set disk "$METRIC_DISK_PERCENT"
        sample_set disk_used_bytes "${STORAGE_VALUE[$id,1]}"
        sample_set disk_available_bytes "${STORAGE_VALUE[$id,2]}"
    fi
}

read_device_counters() {
    local major minor name sectors_read sectors_write
    while read -r major minor name _ _ sectors_read _ _ _ sectors_write _; do
        [ "$name" = "$BLOCK_DEVICE" ] || continue
        [[ "$sectors_read $sectors_write" =~ ^[0-9]+\ [0-9]+$ ]] || return 1
        printf '%s %s %s\n' "$major:$minor:$name" "$sectors_read" "$sectors_write"
        return 0
    done < /proc/diskstats
    return 1
}

collect_device() {
    local id read_sectors write_sectors elapsed=$((SAMPLE_TIME_MS - PREV_DEVICE_TIME))
    DEVICE_STATE=unavailable DEVICE_READ_RATE="" DEVICE_WRITE_RATE=""
    [ -n "$BLOCK_DEVICE" ] || return 0
    if ! read -r id read_sectors write_sectors < <(read_device_counters); then PREV_DEVICE=""; return; fi
    DEVICE_STATE=warming
    if [ "$id" = "$PREV_DEVICE" ] && [ "$elapsed" -gt 0 ] &&
        [ "$read_sectors" -ge "$PREV_DEVICE_READ" ] && [ "$write_sectors" -ge "$PREV_DEVICE_WRITE" ]; then
        DEVICE_READ_RATE=$(((read_sectors - PREV_DEVICE_READ) * 512000 / elapsed))
        DEVICE_WRITE_RATE=$(((write_sectors - PREV_DEVICE_WRITE) * 512000 / elapsed))
        DEVICE_STATE=valid
    fi
    PREV_DEVICE=$id PREV_DEVICE_READ=$read_sectors PREV_DEVICE_WRITE=$write_sectors PREV_DEVICE_TIME=$SAMPLE_TIME_MS
}

read_pressure_source() {
    [ -r "/proc/pressure/$1" ] || return 1
    local line
    while IFS= read -r line; do printf '%s\n' "$line"; done 2>/dev/null < "/proc/pressure/$1"
}

collect_pressure() {
    local resource kind rest field name value
    PRESSURE_VALUES=()
    [ "$PRESSURE_ENABLED" -eq 1 ] || return 0
    for resource in cpu memory io; do
        while read -r kind rest; do
            case "$kind" in some|full) ;; *) continue ;; esac
            # System-level CPU full is undefined, even on kernels exposing zeroes.
            [ "$resource:$kind" != cpu:full ] || continue
            for field in $rest; do
                name=${field%%=*}; value=${field#*=}
                case "$name" in avg10|avg60|avg300) ;; *) continue ;; esac
                [[ "$value" =~ ^[0-9]{1,3}\.[0-9]{2}$ ]] || continue
                [ "$((10#${value%.*} * 100 + 10#${value#*.}))" -le 10000 ] || continue
                PRESSURE_VALUES[$resource,$kind,$name]=$value
            done
        done < <(read_pressure_source "$resource")
    done
}



sort_processes() {
    local identity cpu mem pid
    local -a sortable=()
    for identity in "${!PROC_NAME[@]}"; do
        cpu=${PROC_CPU[$identity]}; [ "$cpu" != N/A ] || cpu=-1
        mem=${PROC_MEM[$identity]}; pid=${identity%%:*}
        if [ "$PROCESS_SORT" = mem ]; then sortable+=("$mem $pid $identity"); else sortable+=("$cpu $pid $identity"); fi
    done
    PROCESS_IDS=(); METRIC_PROCESSES=""
    while read -r _ pid identity; do
        [ -n "$identity" ] || continue
        PROCESS_IDS+=("$identity")
        METRIC_PROCESSES+="${METRIC_PROCESSES:+$'\n'}$pid ${PROC_NAME[$identity]} ${PROC_CPU[$identity]} ${PROC_MEM[$identity]}"
    done < <(printf '%s\n' "${sortable[@]}" | LC_ALL=C sort -k1,1nr -k2,2n)
    METRIC_PROCESS_COUNT=${#PROCESS_IDS[@]}
    filter_processes
}

filter_processes() {
    local identity haystack needle=${PROCESS_FILTER,,}
    FILTERED_IDS=()
    for identity in "${PROCESS_IDS[@]}"; do
        haystack="${identity%%:*} ${PROC_NAME[$identity],,}"
        [[ "$haystack" = *"$needle"* ]] && FILTERED_IDS+=("$identity")
    done
    if [ -z "$SELECTED_PROCESS" ] && [ "${#FILTERED_IDS[@]}" -gt 0 ]; then SELECTED_PROCESS=${FILTERED_IDS[0]}; fi
}

selected_identity_matches() {
    local pid=${SELECTED_PROCESS%%:*} line rest
    local -a fields=()
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    IFS= read -r line 2>/dev/null < "/proc/$pid/stat" || return 1
    rest=${line##*) }; read -r -a fields <<< "$rest"
    [ "$pid:${fields[19]:-}" = "$SELECTED_PROCESS" ]
}

collect_process_detail() {
    local pid=${SELECTED_PROCESS%%:*} line rest start argument total=0
    local -a fields=()
    DETAIL_ARGUMENTS="" DETAIL_STATUS=warming
    [ -n "$SELECTED_PROCESS" ] || return 0
    if [ -z "${PROC_NAME[$SELECTED_PROCESS]+set}" ]; then DETAIL_STATUS='exited or unavailable'; return; fi
    if ! selected_identity_matches; then DETAIL_STATUS='exited or identity changed'; return; fi
    DETAIL_STATUS=valid
    [ "$SHOW_ARGUMENTS" -eq 1 ] && [ "$PROCESS_DETAIL" -eq 1 ] || return 0
    if [ ! -r "/proc/$pid/cmdline" ]; then DETAIL_ARGUMENTS='unavailable (permissions or exited)'; return; fi
    while IFS= read -r -n 4096 -d '' argument; do
        argument=${argument:0:4096}
        DETAIL_ARGUMENTS+="${DETAIL_ARGUMENTS:+ }$(safe_display "$argument")"
        total=${#DETAIL_ARGUMENTS}
        [ "$total" -lt 4096 ] || { DETAIL_ARGUMENTS=${DETAIL_ARGUMENTS:0:4096}'~'; break; }
    done 2>/dev/null < "/proc/$pid/cmdline"
    if IFS= read -r line 2>/dev/null < "/proc/$pid/stat"; then
        rest=${line##*) }; read -r -a fields <<< "$rest"; start=${fields[19]:-}
        [ "$pid:$start" = "$SELECTED_PROCESS" ] && return 0
    fi
    DETAIL_ARGUMENTS="" DETAIL_STATUS='exited or identity changed'
}

export_fields() {
    EXPORT_KEYS=(schema_version app_version session_id sample_sequence timestamp_utc elapsed_ms interval_ms text_encoding disk_path interface)
    EXPORT_VALUES=(1 "$VERSION" "$SESSION_ID" "$SAMPLE_SEQUENCE" "$SAMPLE_UTC" "$((SAMPLE_TIME_MS - SAMPLE_START_MS))" "$SAMPLE_INTERVAL_MS" percent-bytes "$DISK_PATH" "$METRIC_NET_INTERFACE")
    EXPORT_TYPES=(number text text number text number number text text text)
    local key
    for key in cpu ram memory_used_bytes memory_total_bytes swap swap_used_bytes swap_total_bytes disk disk_used_bytes disk_available_bytes rx tx temp; do
        EXPORT_KEYS+=("$key" "${key}_state")
        EXPORT_VALUES+=("${SAMPLE_VALUE[$key]:-}" "${SAMPLE_STATE[$key]:-unavailable}")
        EXPORT_TYPES+=(number text)
    done
}

csv_line() {
    local header=${1:-0} index value separator=""
    export_fields
    for ((index=0; index<${#EXPORT_KEYS[@]}; index++)); do
        if [ "$header" -eq 1 ]; then value=${EXPORT_KEYS[$index]}; else
            value=${EXPORT_VALUES[$index]}
            if [ "${EXPORT_TYPES[$index]}" = text ]; then value=$(encode_text "$value"); fi
        fi
        # Text fields are byte-encoded, so no embedded CSV separators remain.
        printf '%s%s' "$separator" "$value"; separator=,
    done
    printf '\n'
}

json_snapshot() {
    local index value separator=""
    export_fields
    printf '{'
    for ((index=0; index<${#EXPORT_KEYS[@]}; index++)); do
        value=${EXPORT_VALUES[$index]}
        printf '%s"%s":' "$separator" "${EXPORT_KEYS[$index]}"
        if [ "${EXPORT_TYPES[$index]}" = number ]; then
            if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then printf '%s' "$value"; else printf 'null'; fi
        else printf '"%s"' "$(encode_text "$value")"; fi
        separator=,
    done
    printf '}\n'
}

record_failure() {
    RECORD_ERROR=$1
    EXIT_STATUS=1
    if [ -n "$RECORD_FD" ]; then exec 9>&-; RECORD_FD=""; fi
    printf 'Warning: recording stopped: %s\n' "$RECORD_ERROR" >&2
}

start_recording() {
    local directory temporary header
    [ -n "$RECORD_PATH" ] || return 0
    directory=${RECORD_PATH%/*}; [ "$directory" != "$RECORD_PATH" ] || directory=.
    [ -n "$directory" ] || directory=/
    # mktemp supplies a private regular inode; hard-link publication fails on any
    # existing destination, including dangling symlinks, without opening that path.
    temporary=$(mktemp -- "$directory/.pcc-record.XXXXXXXX") || return 1
    if ! exec 9> "$temporary"; then rm -f -- "$temporary"; return 1; fi
    if ! ln -T -- "$temporary" "$RECORD_PATH" 2>/dev/null; then
        exec 9>&-; rm -f -- "$temporary"; return 1
    fi
    rm -f -- "$temporary"
    RECORD_FD=9
    header=$(csv_line 1)
    RECORD_BYTES=$((${#header} + 1))
    printf '%s\n' "$header" >&9 || { record_failure 'cannot write header'; return 1; }
}

record_sample() {
    local line bytes
    [ -n "$RECORD_FD" ] || return 0
    line=$(csv_line)
    # Serialization is ASCII; characters and encoded bytes have identical lengths.
    bytes=$((${#line} + 1))
    if [ "$((RECORD_BYTES + bytes))" -gt "$RECORD_LIMIT" ]; then
        record_failure '100 MiB size limit reached'
        return 0
    fi
    if ! printf '%s\n' "$line" >&9; then record_failure 'write failed'; return 0; fi
    RECORD_BYTES=$((RECORD_BYTES + bytes))
}

move_selection() {
    local direction=$1 index found=-1 count=${#FILTERED_IDS[@]}
    [ "$count" -gt 0 ] || return 0
    for ((index=0; index<count; index++)); do
        [ "${FILTERED_IDS[$index]}" != "$SELECTED_PROCESS" ] || { found=$index; break; }
    done
    if [ "$found" -lt 0 ]; then index=0; else index=$((found + direction)); fi
    [ "$index" -ge 0 ] || index=0
    [ "$index" -lt "$count" ] || index=$((count - 1))
    SELECTED_PROCESS=${FILTERED_IDS[$index]}
    PROCESS_DETAIL=0 DETAIL_ARGUMENTS="" DETAIL_STATUS=warming
}

process_view_rows() {
    local identity index selected=-1 limit=$((TERM_LINES - 5)) marker
    [ "$limit" -ge 1 ] || limit=1
    VIEW_ROWS+=("Processes: ${#FILTERED_IDS[@]} | sort $PROCESS_SORT | CPU ${METRIC_PROCESS_CPU_MODE^^} (100%=one core)")
    if [ "$FILTER_EDITING" -eq 1 ]; then VIEW_ROWS+=("Filter> $FILTER_INPUT"); else VIEW_ROWS+=("Filter: ${PROCESS_FILTER:-all} | / edit | Enter details"); fi
    if [ "$PROCESS_DETAIL" -eq 1 ]; then
        identity=$SELECTED_PROCESS
        if [ -z "$identity" ] || [ -z "${PROC_NAME[$identity]+set}" ] || [[ "$DETAIL_STATUS" = exited* ]]; then
            VIEW_ROWS+=("Selected process exited or unavailable" "Esc back | j/k choose another process")
        else
            VIEW_ROWS+=("PID ${identity%%:*}: ${PROC_NAME[$identity]}" "CPU ${PROC_CPU[$identity]}% | Memory ${PROC_MEM[$identity]}%")
            # Split the cached fields into lines without re-reading the process.
            local -a details=()
            IFS='|' read -r -a details <<< "${PROC_DETAILS[$identity]}"
            VIEW_ROWS+=("${details[@]}" "Details: $DETAIL_STATUS | a toggle arguments")
            [ "$SHOW_ARGUMENTS" -eq 0 ] || VIEW_ROWS+=("Args: ${DETAIL_ARGUMENTS:-warming; r refreshes}")
        fi
        return
    fi
    [ "${#FILTERED_IDS[@]}" -gt 0 ] || { VIEW_ROWS+=("No matching processes"); return; }
    for ((index=0; index<${#FILTERED_IDS[@]}; index++)); do
        [ "${FILTERED_IDS[$index]}" != "$SELECTED_PROCESS" ] || selected=$index
    done
    if [ "$selected" -lt 0 ]; then VIEW_ROWS+=("Selection exited/filtered; j/k selects again"); fi
    if [ "$selected" -ge 0 ] && [ "$selected" -lt "$PROCESS_OFFSET" ]; then PROCESS_OFFSET=$selected; fi
    if [ "$selected" -ge "$((PROCESS_OFFSET + limit))" ]; then PROCESS_OFFSET=$((selected - limit + 1)); fi
    [ "$PROCESS_OFFSET" -lt "${#FILTERED_IDS[@]}" ] || PROCESS_OFFSET=0
    for ((index=PROCESS_OFFSET; index<${#FILTERED_IDS[@]} && index<PROCESS_OFFSET+limit; index++)); do
        identity=${FILTERED_IDS[$index]}; marker=' '
        [ "$identity" != "$SELECTED_PROCESS" ] || marker='>'
        VIEW_ROWS+=("$marker ${identity%%:*} CPU ${PROC_CPU[$identity]}% MEM ${PROC_MEM[$identity]}% ${PROC_NAME[$identity]}")
    done
}

pressure_rows() {
    local resource kind
    VIEW_ROWS+=("Pressure: stalled time %, 10s / 60s / 300s")
    for resource in cpu memory io; do
        for kind in some full; do
            [ "$resource:$kind" != cpu:full ] || continue
            VIEW_ROWS+=("$resource $kind: ${PRESSURE_VALUES[$resource,$kind,avg10]:-N/A} / ${PRESSURE_VALUES[$resource,$kind,avg60]:-N/A} / ${PRESSURE_VALUES[$resource,$kind,avg300]:-N/A}")
        done
    done
}

storage_view_rows() {
    local id index start=$STORAGE_OFFSET inode alias
    VIEW_ROWS+=("Capacity: selected filesystems (j/k scroll)")
    [ "$DEVICE_STATE" = valid ] && VIEW_ROWS+=("$BLOCK_DEVICE read $(format_network_rate "$DEVICE_READ_RATE") write $(format_network_rate "$DEVICE_WRITE_RATE")") ||
        VIEW_ROWS+=("Device I/O: ${BLOCK_DEVICE:-choose --device NAME} ($DEVICE_STATE)")
    for ((index=start; index<${#STORAGE_IDS[@]}; index++)); do
        id=${STORAGE_IDS[$index]}; alias=${STORAGE_ALIAS[$id]:-}
        VIEW_ROWS+=("$(safe_display "${STORAGE_PATH[$id]}") -> $(safe_display "${STORAGE_MOUNT[$id]}") [${STORAGE_TYPE[$id]}] ${STORAGE_STATE[$id]}")
        if [ "${STORAGE_STATE[$id]}" = valid ]; then
            inode=N/A
            if [ "${STORAGE_VALUE[$id,4]:-0}" -gt 0 ] && [ -n "${STORAGE_VALUE[$id,7]}" ]; then inode=${STORAGE_VALUE[$id,7]}%; fi
            VIEW_ROWS+=(" Used ${STORAGE_VALUE[$id,3]}% | Free $(format_bytes "${STORAGE_VALUE[$id,2]}") | Inodes $inode")
        fi
        [ -z "$alias" ] || VIEW_ROWS+=(" Same filesystem:$alias")
    done
}

render_focused_view() {
    local width=$TERM_COLS index limit=$((TERM_LINES - 2)) offset
    case "${layout:-$LAYOUT}" in
        compact) [ "$width" -le 88 ] || width=88 ;;
        mini) [ "$width" -le 59 ] || width=59 ;;
        micro) [ "$width" -le 44 ] || width=44 ;;
        *) [ "$width" -le 120 ] || width=120 ;;
    esac
    [ "$width" -ge 1 ] || width=1
    VIEW_ROWS=()
    if [ "$EVENTS_VISIBLE" -eq 1 ]; then
        VIEW_ROWS+=("Events: $EVENT_COUNT retained | j/k scroll | e close")
        for ((offset=EVENT_OFFSET; offset<EVENT_COUNT; offset++)); do
            index=$(((EVENT_HEAD - offset - 1 + EVENT_CAPACITY) % EVENT_CAPACITY))
            VIEW_ROWS+=("${EVENTS[$index]}")
        done
        [ "$EVENT_COUNT" -gt 0 ] || VIEW_ROWS+=("No recorded transitions this session")
    else
        case "$VIEW" in
            processes) process_view_rows ;;
            storage) storage_view_rows ;;
            network)
                VIEW_ROWS+=("Interface: ${METRIC_NET_INTERFACE:-N/A} | n cycles" "$METRIC_INTERFACE" "Gateway: ${METRIC_GATEWAY:-N/A}" "RX $METRIC_NET_RX_RATE | TX $METRIC_NET_TX_RATE")
                mapfile -t VIEW_ROWS < <(printf '%s\n' "${VIEW_ROWS[@]}"; history_rows "$width") ;;
            pressure) pressure_rows ;;
        esac
    fi
    print_fit_line "$width" "PCC ${VIEW^^}$(pause_label) | $(alert_summary)"
    for ((index=0; index<${#VIEW_ROWS[@]} && index<limit; index++)); do print_fit_line "$width" "${VIEW_ROWS[$index]}"; done
    if [ "$TERM_LINES" -ge 2 ]; then print_fit_line "$width" '1 overview 2 proc 3 disk 4 net 5 pressure | q ?'; fi
}



valid_profile_name() {
    [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$ ]]
}

# Resolve the profile before reading either file, regardless of option order.
# Skip option values so a directory named --profile cannot become a selector.
select_profile() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --profile)
                [ "$#" -ge 2 ] || die "--profile requires a name"
                valid_profile_name "$2" || die "invalid profile name (letters, digits, underscore, hyphen; max 64)"
                PROFILE=$2; shift 2 ;;
            --interval|--layout|--disk|--watch-disk|--device|--view|--format|--record)
                [ "$#" -ge 2 ] || return 0
                shift 2 ;;
            *) shift ;;
        esac
    done
}

list_profiles() {
    local directory="${XDG_CONFIG_HOME:-$HOME/.config}/pc-command-center/profiles" file name count=0
    printf 'Profiles: %s\n' "$(safe_display "$directory")"
    for file in "$directory"/*.conf; do
        [ -f "$file" ] || continue
        name=${file##*/}; name=${name%.conf}
        valid_profile_name "$name" || continue
        printf '  %s\n' "$name"
        count=$((count + 1))
    done
    [ "$count" -gt 0 ] || printf '  (none; create NAME.conf in this directory)\n'
    return 0
}

doctor_line() {
    printf '%-5s %-17s %s\n' "$1" "$2" "$(safe_display "$3")"
}

doctor_file() {
    local path=$1 label=$2 advice=$3
    if [ -r "$path" ]; then doctor_line OK "$label" "$path is readable"
    else doctor_line WARN "$label" "$path unavailable; $advice"; fi
}

doctor_probe() {
    # All command probes have a deadline; never run install/configuration tools.
    command -v timeout >/dev/null 2>&1 || return 125
    LC_ALL=C timeout -k 1 2 "$@" 2>/dev/null
}

run_doctor() {
    local command package missing=0 directory config state id resource reading sensors_ok=0 line scope
    local -a ip_address=(ip -o -4 address show) ip_route=(ip -4 route show default)
    local required='awk cat date df free getconf grep head hostname ip ps sort sed stty tput uptime whoami timeout mktemp ln rm'
    printf 'PC Command Center %s diagnostics\n' "$VERSION"
    printf 'Read-only checks; OK=available, WARN=limited/optional, FAIL=missing requirement.\n'
    doctor_line INFO Bash "$BASH_VERSION (requires Bash 4+)"
    printf '\nDependencies\n'
    for command in $required; do
        case "$command" in
            awk) package='mawk or gawk' ;;
            free|ps|uptime) package=procps ;;
            ip) package=iproute2 ;;
            tput) package=ncurses-bin ;;
            hostname) package=hostname ;;
            grep|sed) package=$command ;;
            *) package=coreutils ;;
        esac
        if command -v "$command" >/dev/null 2>&1; then doctor_line OK "$command" available
        else doctor_line FAIL "$command" "not found in PATH; install $package with your package manager"; missing=$((missing + 1)); fi
    done
    directory=${XDG_CONFIG_HOME:-$HOME/.config}
    config=$directory/pc-command-center.conf
    printf '\nConfiguration\n'
    if [ -r "$config" ] && [ -f "$config" ]; then doctor_line OK 'Base config' "$config"
    elif [ -e "$config" ]; then doctor_line WARN 'Base config' "$config is not a readable regular file; correct its type/permissions"
    else doctor_line INFO 'Base config' "optional file absent; using defaults ($config)"; fi
    if [ -n "$PROFILE" ]; then doctor_line OK Profile "$PROFILE ($directory/pc-command-center/profiles/$PROFILE.conf)"
    else doctor_line INFO Profile 'none selected; use --list-profiles or --profile NAME'; fi
    if [ "$CONFIG_WARNINGS" -gt 0 ]; then
        doctor_line WARN Validation "$CONFIG_WARNINGS config entries/pairs ignored; correct the warnings above and rerun --doctor"
    else doctor_line OK Validation 'no ignored configuration entries'; fi
    doctor_line INFO Precedence 'defaults < base config < selected profile < CLI'
    doctor_line INFO Settings "refresh=${REFRESH_INTERVAL}s layout=$LAYOUT color=$ENABLE_COLOR disk=$DISK_PATH"

    printf '\nTerminal and core telemetry\n'
    if [ -t 0 ] && [ -t 1 ]; then doctor_line OK Terminal 'interactive stdin/stdout'
    else doctor_line INFO Terminal 'noninteractive; snapshots/--format work, live mode and --record require a TTY'; fi
    if [ -n "${TERM:-}" ] && [ "$TERM" != dumb ] && command -v tput >/dev/null 2>&1 &&
        doctor_probe tput -T "$TERM" cols >/dev/null; then
        doctor_line OK Terminfo "$TERM capabilities available"
    else doctor_line WARN Terminfo 'missing/unknown TERM or tput capabilities; use a configured terminal or --once --no-color'; fi
    doctor_file /proc/stat CPU 'use a Linux host with procfs mounted and readable'
    doctor_file /proc/loadavg Load 'check procfs access; load will show unavailable'
    doctor_file /proc/uptime Clock 'check procfs access; elapsed sampling needs this source'
    if command -v free >/dev/null 2>&1 && doctor_probe free -b >/dev/null; then doctor_line OK Memory 'free -b responds'
    else doctor_line WARN Memory 'free -b failed/timed out; check procps installation and /proc/meminfo access'; fi
    if command -v ps >/dev/null 2>&1 && doctor_probe ps -p "$$" -o pid= >/dev/null; then doctor_line OK Processes 'ps responds; individual /proc/PID files can still be permission-restricted'
    else doctor_line WARN Processes 'ps failed/timed out; check procps and procfs permissions'; fi

    printf '\nFilesystems and device I/O\n'
    if command -v df >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 && [ -r /proc/self/mountinfo ]; then
        collect_storage
        for id in "${STORAGE_IDS[@]}"; do
            state=${STORAGE_STATE[$id]}
            case "$state" in
                valid) doctor_line OK Filesystem "${STORAGE_PATH[$id]}: capacity available (${STORAGE_TYPE[$id]})" ;;
                unsupported) doctor_line WARN Filesystem "${STORAGE_PATH[$id]}: ${STORAGE_TYPE[$id]} remote/FUSE/autofs probes are unsupported; select a local path" ;;
                *) doctor_line WARN Filesystem "${STORAGE_PATH[$id]}: missing/changed mount, permission error, or bounded df failure; check the mount and rerun" ;;
            esac
            if [ "$state" = valid ] && [ "${STORAGE_VALUE[$id,4]:-0}" -gt 0 ]; then doctor_line OK Inodes "${STORAGE_PATH[$id]}: inode accounting available"
            else doctor_line WARN Inodes "${STORAGE_PATH[$id]}: no usable inode totals; N/A is expected"; fi
        done
    else doctor_line WARN Filesystem 'df/timeout or readable mountinfo unavailable; restore the dependencies/procfs access'; fi
    if [ -z "$BLOCK_DEVICE" ]; then doctor_line INFO 'Device I/O' 'disabled; choose a kernel device name with --device NAME (not a /dev/path)'
    elif [ -r /proc/diskstats ] && read_device_counters >/dev/null; then doctor_line OK 'Device I/O' "$BLOCK_DEVICE counters found; two samples are needed for rates"
    else doctor_line WARN 'Device I/O' "$BLOCK_DEVICE absent/unreadable; check /proc/diskstats and select the correct --device name"; fi

    printf '\nNetwork\n'
    doctor_file /proc/net/dev 'Byte counters' 'check procfs network access; RX/TX cannot be measured'
    if [ -n "$NETWORK_INTERFACE" ]; then
        if [ -e "/sys/class/net/$NETWORK_INTERFACE" ]; then doctor_line OK Interface "$NETWORK_INTERFACE exists"
        else doctor_line WARN Interface "$NETWORK_INTERFACE disappeared; select an existing interface in config"; fi
    else doctor_line INFO Interface 'automatic selection from default route/active IPv4; n cycles live interfaces'; fi
    if command -v ip >/dev/null 2>&1; then
        scope='all interfaces'
        if [ -n "$NETWORK_INTERFACE" ]; then
            scope=$NETWORK_INTERFACE
            ip_address+=(dev "$NETWORK_INTERFACE"); ip_route+=(dev "$NETWORK_INTERFACE")
        fi
        ip_address+=(up scope global)
        if ! reading=$(doctor_probe "${ip_address[@]}"); then doctor_line WARN IPv4 'ip failed/timed out; check iproute2 and network namespace permissions'
        elif [ -n "$reading" ]; then doctor_line OK IPv4 "active global IPv4 address available on $scope; rates need two samples"
        else doctor_line WARN IPv4 "no active global IPv4 address on $scope; connect the interface or inspect network settings"; fi
        if ! reading=$(doctor_probe "${ip_route[@]}"); then doctor_line WARN Gateway 'route query failed/timed out; check iproute2 and namespace permissions'
        elif [ -n "$reading" ]; then doctor_line OK Gateway "default IPv4 route available on $scope"
        else doctor_line WARN Gateway "no default IPv4 route on $scope; gateway N/A is expected (local-only links may be intentional)"; fi
    fi

    printf '\nOptional hardware and pressure\n'
    if command -v sensors >/dev/null 2>&1; then
        if reading=$(doctor_probe sensors); then
            while IFS= read -r line; do
                if [[ "$line" =~ (Package\ id\ 0|Core\ 0|temp1) ]]; then
                    [[ "$line" =~ [+-]?[0-9]+([.][0-9]+)?°?C ]] && sensors_ok=1
                    break
                fi
            done <<< "$reading"
        fi
        if [ "$sensors_ok" -eq 1 ]; then doctor_line OK Temperature 'sensors responds with a usable CPU temperature'
        else doctor_line WARN sensors 'failed/timed out or no usable supported reading; check sensor support/configuration (no automatic changes)'; fi
    else doctor_line INFO sensors 'optional command absent; install lm-sensors for additional readings'; fi
    if [ "$sensors_ok" -eq 0 ]; then
        reading=''
        if [ -r /sys/class/thermal/thermal_zone0/temp ]; then read -r reading < /sys/class/thermal/thermal_zone0/temp; fi
        if [[ "$reading" =~ ^[0-9]+$ ]]; then doctor_line OK Temperature 'thermal_zone0 fallback is readable'
        else doctor_line WARN Temperature 'no supported sensor/fallback; N/A is expected on unsupported or restricted hardware'; fi
    fi
    reading=$(read_battery_metrics)
    if [ -n "$reading" ]; then doctor_line OK Battery "$reading"
    else doctor_line INFO Battery 'no readable supported battery; expected on desktops or restricted hardware'; fi
    if [ "$PRESSURE_ENABLED" -eq 0 ]; then doctor_line INFO Pressure 'disabled by PRESSURE_ENABLED=0'
    else
        collect_pressure
        for resource in cpu memory io; do
            if [ -n "${PRESSURE_VALUES[$resource,some,avg10]:-}" ]; then doctor_line OK Pressure "$resource some averages available"
            else doctor_line WARN Pressure "$resource unavailable/unsupported; kernel PSI or procfs permissions may limit this source"; fi
        done
    fi
    printf '\nRequired dependencies missing: %s. Optional limitations do not fail this check.\n' "$missing"
    [ "$missing" -eq 0 ]
}

main() {
    select_profile "$@"
    read_config
    if [ -n "$PROFILE" ]; then
        local profile_file="${XDG_CONFIG_HOME:-$HOME/.config}/pc-command-center/profiles/$PROFILE.conf"
        if [ ! -f "$profile_file" ] || [ ! -r "$profile_file" ]; then die "cannot read profile $PROFILE; create $profile_file or use --list-profiles"; fi
        read_config "$profile_file"
    fi
    parse_args "$@"
    if [ "$DOCTOR" -eq 1 ] || [ "$LIST_PROFILES" -eq 1 ]; then
        if [ "$DOCTOR" -eq 1 ]; then
            if [ "$OUTPUT_FORMAT" != terminal ] || [ -n "$RECORD_PATH" ]; then die "--doctor cannot be combined with --format json/csv or --record"; fi
            run_doctor
        else list_profiles; fi
        return $?
    fi
    [ "$OUTPUT_FORMAT" = terminal ] || ONCE=1
    if [ -n "$RECORD_PATH" ] && { [ "$ONCE" -eq 1 ] || [ ! -t 0 ] || [ ! -t 1 ]; }; then
        die "--record requires an interactive terminal and cannot be combined with --once/--format"
    fi
    if [ ! -t 0 ] || [ ! -t 1 ]; then ONCE=1; fi
    setup_colors
    init_cpu_sample
    sleep 0.25
    if [ "$ONCE" -eq 1 ]; then
        collect_sample
        case "$OUTPUT_FORMAT" in
            json) json_snapshot ;;
            csv) csv_line 1; csv_line ;;
            terminal) render_dashboard ;;
        esac
    else
        start_recording || die "cannot create recording (destination must be new and parent writable)"
        run_live
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
