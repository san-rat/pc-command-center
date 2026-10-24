#!/bin/bash

# PC Command Center
# A lightweight terminal dashboard for Ubuntu/Linux systems.

VERSION="2.0.0"
REFRESH_INTERVAL=5
ENABLE_COLOR=1
ONCE=0
LAYOUT=auto
DISK_PATH=/
NETWORK_INTERFACE=""
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
  --version           Show the version and exit
  --help              Show this help message

Live telemetry:
  Network RX/TX rates use byte-counter deltas for the selected/default route interface.
  Live process CPU uses interval deltas; --once labels ps lifetime averages as AVG.
  Battery and per-core CPU readings appear when hardware data is available (wide view).

Configuration:
  ~/.config/pc-command-center.conf (or $XDG_CONFIG_HOME/pc-command-center.conf)
  Defaults < config < CLI flags. Literal KEY=value entries; no shell expansion.
  REFRESH_INTERVAL=1..999999, ENABLE_COLOR=0|1, DISK_PATH=directory,
  NETWORK_INTERFACE=interface (empty for all), LAYOUT=auto|compact|mini|micro|tiny|wide.
  CPU_WARN/CPU_CRIT=60/85, RAM_WARN/RAM_CRIT=75/90, DISK_WARN/DISK_CRIT=75/90,
  TEMP_WARN/TEMP_CRIT=70/85 (Celsius), LOAD_WARN/LOAD_CRIT=70/100,
  SWAP_WARN/SWAP_CRIT=50/80. These pairs show defaults; set each key separately.
  Thresholds: CPU/RAM/DISK/SWAP 0..100, TEMP 0..999, LOAD 0..999999; WARN < CRIT.
  Invalid entries warn once and are ignored; invalid threshold pairs are ignored.

Live controls:
  q     Quit
  r     Refresh now
  +     Refresh faster, down to 1 second
  -     Refresh slower
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
        ENABLE_COLOR) [[ "$value" == 0 || "$value" == 1 ]] ;;
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
    local file="${XDG_CONFIG_HOME:-$HOME/.config}/pc-command-center.conf"
    local line key value metric warn_key crit_key warn crit
    local line_number=0
    local -A thresholds=()

    [ -e "$file" ] || return 0
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        printf 'Warning: cannot read config %s; ignored\n' "$file" >&2
        return 0
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        line_number=$((line_number + 1))
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        [[ -z "$line" || "$line" == \#* ]] && continue
        if ! [[ "$line" =~ ^([A-Z][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            printf 'Warning: %s:%s: invalid config entry; ignored\n' "$file" "$line_number" >&2
            continue
        fi
        key=${BASH_REMATCH[1]}
        value=${BASH_REMATCH[2]}
        if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
            value=${value:1:${#value}-2}
        fi
        if ! valid_setting "$key" "$value"; then
            printf 'Warning: %s:%s: invalid %s; ignored\n' "$file" "$line_number" "$key" >&2
            continue
        fi
        case "$key" in
            *_WARN|*_CRIT) thresholds[$key]=$((10#$value)) ;;
            REFRESH_INTERVAL) REFRESH_INTERVAL=$((10#$value)) ;;
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
            printf 'Warning: %s: invalid %s thresholds; pair ignored\n' "$file" "$metric" >&2
        fi
    done
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
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

strip_ansi() {
    printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g'
}

visible_length() {
    local plain
    plain=$(strip_ansi "$1")
    printf '%s' "${#plain}"
}

pad_ansi() {
    local text="$1"
    local width="$2"
    local plain
    local visible

    [ "$width" -lt 0 ] && width=0

    plain=$(strip_ansi "$text")
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

    visible=$(visible_length "$text")
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

    read_cpu_times
    diff_idle=$((CPU_IDLE - PREV_CPU_IDLE))
    diff_total=$((CPU_TOTAL - PREV_CPU_TOTAL))
    CPU_DIFF_TOTAL=$diff_total

    if [ "$diff_total" -gt 0 ]; then
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
    METRIC_NET_RX_RATE=N/A
    METRIC_NET_TX_RATE=N/A
    if [ -z "$interface" ] || ! read -r rx tx < <(read_network_counters "$interface"); then
        PREV_NET_INTERFACE=""
        return
    fi

    now=${EPOCHSECONDS:-$SECONDS}
    elapsed=$((now - PREV_NET_TIME))
    if [ "$interface" = "$PREV_NET_INTERFACE" ] && [ "$elapsed" -gt 0 ] &&
        [ "$rx" -ge "$PREV_NET_RX" ] && [ "$tx" -ge "$PREV_NET_TX" ]; then
        METRIC_NET_RX_RATE=$(format_network_rate "$(((rx - PREV_NET_RX) / elapsed))")
        METRIC_NET_TX_RATE=$(format_network_rate "$(((tx - PREV_NET_TX) / elapsed))")
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
    local pid line previous delta percent mem name
    local -A current_ticks=() percentages=()
    local -a process_lines=()
    local sorted_processes

    while read -r pid ticks; do
        [[ "$pid" =~ ^[0-9]+$ && "$ticks" =~ ^[0-9]+$ ]] || continue
        current_ticks[$pid]=$ticks
    done < <(read_process_ticks)

    if [ "$CPU_DIFF_TOTAL" -gt 0 ]; then
        for pid in "${!current_ticks[@]}"; do
            previous=${PREV_PROC_TICKS[$pid]:-${current_ticks[$pid]}}
            delta=$((current_ticks[$pid] - previous))
            [ "$delta" -lt 0 ] && delta=0
            percent=$((delta * CPU_COUNT * 1000 / CPU_DIFF_TOTAL))
            printf -v percent '%d.%d' "$((percent / 10))" "$((percent % 10))"
            percentages[$pid]=$percent
        done
    fi

    for pid in "${!current_ticks[@]}"; do PREV_PROC_TICKS[$pid]=${current_ticks[$pid]}; done
    for pid in "${!PREV_PROC_TICKS[@]}"; do
        [ -n "${current_ticks[$pid]+present}" ] || unset 'PREV_PROC_TICKS[$pid]'
    done

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+(.*)[[:space:]]+([0-9.]+)[[:space:]]+([0-9.]+)$ ]] || continue
        pid=${BASH_REMATCH[1]}
        [ "$pid" = "$$" ] && continue
        name=${BASH_REMATCH[2]}
        mem=${BASH_REMATCH[4]}
        percent=${percentages[$pid]:-0.0}
        process_lines+=("$percent $pid $name $mem")
    done < <(ps -eo pid=,comm=,%cpu=,%mem= 2>/dev/null)
    sorted_processes=$(printf '%s\n' "${process_lines[@]}" | sort -k1,1nr)
    METRIC_PROCESSES=""
    while IFS= read -r line; do
        [[ "$line" =~ ^([0-9]+\.[0-9]+)[[:space:]]+([0-9]+)[[:space:]]+(.*)[[:space:]]+([0-9.]+)$ ]] || continue
        percent=${BASH_REMATCH[1]}
        pid=${BASH_REMATCH[2]}
        name=${BASH_REMATCH[3]}
        mem=${BASH_REMATCH[4]}
        METRIC_PROCESSES+="${METRIC_PROCESSES:+$'\n'}$pid $name $percent $mem"
    done <<< "$sorted_processes"
    METRIC_PROCESS_CPU_MODE=now
}

read_process_ticks() {
    local path pid line rest
    local -a fields

    for path in /proc/[0-9]*/stat; do
        [ -r "$path" ] || continue
        pid=${path#/proc/}
        pid=${pid%/stat}
        [ "$pid" = "$$" ] && continue
        IFS= read -r line < "$path" || continue
        rest=${line##*) }
        read -r -a fields <<< "$rest"
        [ "${#fields[@]}" -ge 13 ] || continue
        [[ "${fields[11]}" =~ ^[0-9]+$ && "${fields[12]}" =~ ^[0-9]+$ ]] || continue
        printf '%s %s\n' "$pid" "$((fields[11] + fields[12]))"
    done
}

collect_metrics() {
    local cores load_five load_fifteen line first second third fourth fifth
    local route_interface route_gateway

    # CPU counters must advance in the parent shell, not a command substitution.
    get_cpu_usage >/dev/null

    read -r METRIC_MEM_USED METRIC_MEM_TOTAL METRIC_MEM_PERCENT METRIC_SWAP_USED METRIC_SWAP_TOTAL METRIC_SWAP_PERCENT < <(
        free -b | awk '
            function human(bytes, unit, units) {
                split("B Ki Mi Gi Ti Pi Ei", units, " ")
                unit = 1
                while (bytes >= 1024 && unit < 7) { bytes /= 1024; unit++ }
                return sprintf(bytes < 10 && unit > 1 ? "%.1f%s" : "%d%s", bytes, units[unit])
            }
            function percent(used, total) {
                used = int(used / 1048576)
                total = int(total / 1048576)
                return total > 0 ? int(used * 100 / total) : 0
            }
            /Mem:/ { mem = human($3) " " human($2) " " percent($3, $2) }
            /Swap:/ { swap = human($3) " " human($2) " " percent($3, $2) }
            END { print (mem ? mem : "N/A N/A 0"), (swap ? swap : "0B 0B 0") }
        '
    )

    read -r METRIC_DISK_USED METRIC_DISK_TOTAL METRIC_DISK_AVAILABLE METRIC_DISK_PERCENT < <(
        df -hP -- "$DISK_PATH" 2>/dev/null | awk 'NR==2 {print $3, $2, $4, $5}'
    ) || true
    METRIC_DISK_PERCENT=${METRIC_DISK_PERCENT%\%}
    METRIC_DISK_PERCENT=${METRIC_DISK_PERCENT:-0}
    METRIC_DISK_LABEL=ROOT
    [ "$DISK_PATH" = / ] || METRIC_DISK_LABEL=DISK

    read -r METRIC_LOAD_ONE load_five load_fifteen _ < /proc/loadavg
    METRIC_LOAD="$METRIC_LOAD_ONE $load_five $load_fifteen"
    cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')
    [[ "$cores" =~ ^[0-9]+$ ]] || cores=1
    [ "$cores" -lt 1 ] && cores=1
    CPU_COUNT=$cores
    METRIC_LOAD_PERCENT=$(awk -v load_one="$METRIC_LOAD_ONE" -v cores="$cores" 'BEGIN {printf "%d", load_one * 100 / cores}')

    METRIC_TEMP=$(get_temperature)
    METRIC_TEMP_PERCENT=$(temperature_number "$METRIC_TEMP")
    METRIC_TEMP_SHORT=$METRIC_TEMP
    [ "$METRIC_TEMP" = "Not available" ] && METRIC_TEMP_SHORT="N/A"

    if [ "$LIVE_MODE" -eq 1 ]; then
        collect_live_processes
    else
        METRIC_PROCESSES=$(ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu 2>/dev/null)
        METRIC_PROCESS_CPU_MODE=avg
    fi
    METRIC_PROCESS_COUNT=0
    while IFS= read -r line; do
        [ -n "$line" ] && METRIC_PROCESS_COUNT=$((METRIC_PROCESS_COUNT + 1))
    done <<< "$METRIC_PROCESSES"

    METRIC_INTERFACES=()
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
        elif [[ "$first" =~ ^[0-9]+:$ ]] && [ "${#METRIC_INTERFACES[@]}" -lt 4 ] &&
            { [ -z "$NETWORK_INTERFACE" ] || [ "${second%%@*}" = "$NETWORK_INTERFACE" ]; }; then
            [ "${#METRIC_INTERFACES[@]}" -eq 0 ] && METRIC_INTERFACE="$second $fourth"
            METRIC_INTERFACES+=("$second  $fourth")
        fi
    done < <(ip -o -4 -batch - 2>/dev/null <<< $'address show up scope global\nroute show default')

    collect_network_metrics
    METRIC_BATTERY=$(read_battery_metrics) || METRIC_BATTERY=""

    METRIC_UPTIME=$(uptime -p)
    METRIC_HOST=$(hostname)
    METRIC_USER=$(whoami)
    METRIC_TIME=$(date '+%Y-%m-%d %H:%M:%S')
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
    local number

    number=$(printf '%s' "$temp" | grep -Eo '[0-9]+([.][0-9]+)?' | head -n 1)
    number=${number%.*}
    [[ "$number" =~ ^[0-9]+$ ]] && printf '%s' "$number" || printf '0'
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

    printf '%s\n' "$(pad_ansi "$text" "$width")"
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
    local -a rows

    [ "$name_width" -lt 8 ] && name_width=8
    [ "$name_width" -gt 28 ] && name_width=28

    rows+=("PID    COMMAND$(repeat_char " " "$((name_width - 7))")     CPU${METRIC_PROCESS_CPU_MODE:+ }${METRIC_PROCESS_CPU_MODE^^}    MEM")

    while IFS= read -r line; do
        rows+=("$line")
    done < <(format_process_rows "$name_width" "$limit" 6)

    if [ "${#rows[@]}" -eq 1 ]; then
        rows+=("No process data available")
    fi

    panel "$width" "Top Processes" "${rows[@]}"
}

render_header() {
    local width="$1"
    local title="${BOLD}${CYAN}PC COMMAND CENTER${RESET}"
    local status

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
    title="${BOLD}${CYAN}PC COMMAND CENTER${RESET}"
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

    [ "$name_width" -lt 10 ] && name_width=10
    [ "$name_width" -gt 30 ] && name_width=30

    print_fit_line "$width" "${BLUE}TOP${RESET}"
    print_fit_line "$width" "PID    COMMAND$(repeat_char " " "$((name_width - 7))")    CPU${METRIC_PROCESS_CPU_MODE:+ }${METRIC_PROCESS_CPU_MODE^^}   MEM"

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
            printf "%5s  %-*s %*s %*s\n", $1, nw, name, pw, $(NF - 1) "%", pw, $NF "%"
            count++
        }
    ' <<< "$METRIC_PROCESSES"
}

top_process_summary() {
    local name_width="$1"

    [ "$name_width" -lt 6 ] && name_width=6
    awk -v nw="$name_width" '
        NF >= 4 {
            name = $2
            for (i = 3; i <= NF - 2; i++) name = name " " $i
            if (length(name) > nw) name = substr(name, 1, nw - 1) "~"
            printf "%s %s%%", name, $(NF - 1)
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

    print_fit_line "$width" "${BOLD}${CYAN}PCC MINI${RESET} | $METRIC_HOST | ${REFRESH_INTERVAL}s"
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
        print_fit_line "$width" "TOP ${METRIC_PROCESS_CPU_MODE^^} $(top_process_summary "$((width - 20))")"
    fi

    printf '%s\n' "$(repeat_char "-" "$width")"
    print_fit_line "$width" "q quit | r refresh"
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

    print_fit_line "$width" "${BOLD}${CYAN}PCC MICRO${RESET} | ${REFRESH_INTERVAL}s"
    printf '%s\n' "$(repeat_char "-" "$width")"
    print_fit_line "$width" "CPU $(colorize "$cpu_color" "${METRIC_CPU}%") | RAM $(colorize "$mem_color" "${METRIC_MEM_PERCENT}%")"
    print_fit_line "$width" "DSK $(colorize "$disk_color" "${METRIC_DISK_PERCENT}%") | TMP $(colorize "$temp_color" "$METRIC_TEMP_SHORT")"
    print_fit_line "$width" "LOAD $METRIC_LOAD_ONE | SWAP ${METRIC_SWAP_PERCENT}%"
    [ "$lines" -ge 10 ] && print_fit_line "$width" "$METRIC_DISK_LABEL ${METRIC_DISK_AVAILABLE:-N/A} free"
    printf '%s\n' "$(repeat_char "-" "$width")"
    print_fit_line "$width" "q quit | r refresh"
}

render_tiny_fallback() {
    local cols="$1"
    local width="$cols"

    [ "$width" -lt 1 ] && width=1

    print_fit_line "$width" "${BOLD}${CYAN}PCC${RESET} ${REFRESH_INTERVAL}s"
    print_fit_line "$width" "CPU ${METRIC_CPU}% RAM ${METRIC_MEM_PERCENT}%"
    print_fit_line "$width" "DSK ${METRIC_DISK_PERCENT}%"
    print_fit_line "$width" "q/r"
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
    printf '%s\n' "$(repeat_char "-" "$width")"
    print_fit_line "$width" "Controls: q quit | r refresh | + faster | - slower"
}

render_wide_dashboard() {
    local cols
    local lines
    local width
    local left_width
    local right_width
    local i
    local max_lines
    local process_limit=7
    local -a left_panel
    local -a right_panel

    cols=$TERM_COLS
    lines=$TERM_LINES

    width="$cols"
    [ "$width" -gt 120 ] && width=120
    [ "$width" -lt 36 ] && width=36

    if [ "$lines" -le 24 ]; then
        process_limit=5
    fi

    render_header "$width"

    if [ "$width" -ge 96 ]; then
        left_width=$(((width - 2) / 2))
        right_width=$((width - 2 - left_width))

        mapfile -t left_panel < <(system_panel "$left_width")
        mapfile -t right_panel < <(network_panel "$right_width")

        max_lines=${#left_panel[@]}
        [ "${#right_panel[@]}" -gt "$max_lines" ] && max_lines=${#right_panel[@]}

        for ((i = 0; i < max_lines; i++)); do
            printf '%s  %s\n' "${left_panel[$i]:-$(blank_line "$left_width")}" "${right_panel[$i]:-$(blank_line "$right_width")}"
        done
    else
        system_panel "$width"
        network_panel "$width"
    fi

    process_panel "$width" "$process_limit"
    printf '%s\n' "$(repeat_char "-" "$width")"
    printf '%s\n' "$(pad_ansi "Controls: q quit | r refresh | + faster | - slower" "$width")"

    if [ "$LIVE_MODE" -eq 1 ]; then
        tput_cmd ed
    fi
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
    collect_metrics
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
    case "$layout" in
        wide) render_wide_dashboard ;;
        compact) render_compact_dashboard "$cols" "$lines" ;;
        mini) render_mini_dashboard "$cols" "$lines" ;;
        micro) render_micro_dashboard "$cols" "$lines" ;;
        tiny) render_tiny_fallback "$cols" ;;
    esac
    if [ "$LIVE_MODE" -eq 1 ] && [ "$layout" != wide ]; then
        tput_cmd ed
    fi
}

handle_key() {
    local key="$1"

    case "$key" in
        q|Q)
            exit 0
            ;;
        r|R)
            render_dashboard
            NEXT_DRAW=$(( ${EPOCHSECONDS:-$SECONDS} + REFRESH_INTERVAL ))
            ;;
        +|=)
            if [ "$REFRESH_INTERVAL" -gt 1 ]; then
                REFRESH_INTERVAL=$((REFRESH_INTERVAL - 1))
            fi
            render_dashboard
            NEXT_DRAW=$(( ${EPOCHSECONDS:-$SECONDS} + REFRESH_INTERVAL ))
            ;;
        -|_)
            REFRESH_INTERVAL=$((REFRESH_INTERVAL + 1))
            render_dashboard
            NEXT_DRAW=$(( ${EPOCHSECONDS:-$SECONDS} + REFRESH_INTERVAL ))
            ;;
    esac
}

run_live() {
    local key
    local now

    if [ ! -t 0 ] || [ ! -t 1 ]; then
        render_dashboard
        return
    fi

    LIVE_MODE=1
    trap cleanup EXIT
    trap 'exit 0' INT TERM
    trap 'RESIZE_PENDING=1' WINCH
    setup_terminal
    render_dashboard
    NEXT_DRAW=$(( ${EPOCHSECONDS:-$SECONDS} + REFRESH_INTERVAL ))

    while true; do
        if read -rsn1 -t 0.1 key; then
            handle_key "$key"
        fi

        now=${EPOCHSECONDS:-$SECONDS}
        if [ "$RESIZE_PENDING" -eq 1 ]; then
            NEXT_DRAW=0
        fi
        if [ "$now" -ge "$NEXT_DRAW" ]; then
            render_dashboard
            NEXT_DRAW=$(( ${EPOCHSECONDS:-$SECONDS} + REFRESH_INTERVAL ))
        fi
    done
}

main() {
    read_config
    parse_args "$@"
    setup_colors
    init_cpu_sample
    sleep 0.25

    if [ "$ONCE" -eq 1 ]; then
        render_dashboard
    else
        run_live
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
