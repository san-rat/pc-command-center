#!/bin/bash

# PC Command Center
# A lightweight terminal dashboard for Ubuntu/Linux systems.

REFRESH_INTERVAL=5
ENABLE_COLOR=1
ONCE=0
WIDE_MODE=0
LIVE_MODE=0
TERMINAL_READY=0
STTY_STATE=""
PREV_CPU_IDLE=0
PREV_CPU_TOTAL=0

RESET=""
BOLD=""
DIM=""
RED=""
GREEN=""
YELLOW=""
BLUE=""
CYAN=""
MAGENTA=""

usage() {
    cat <<'EOF'
PC Command Center

Usage:
  ./pc-command-center.sh [options]

Options:
  --interval SECONDS  Set the refresh interval. Default: 5
  --no-color          Disable terminal colors
  --once              Print one dashboard snapshot and exit
  --wide              Use the roomier wide dashboard layout
  --help              Show this help message

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

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --interval)
                [ "$#" -ge 2 ] || die "--interval requires a value"
                [[ "$2" =~ ^[0-9]+$ ]] || die "--interval must be a positive integer"
                [ "$2" -ge 1 ] || die "--interval must be at least 1"
                REFRESH_INTERVAL="$2"
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
                WIDE_MODE=1
                shift
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
        MAGENTA=$(tput_cmd setaf 5)
        CYAN=$(tput_cmd setaf 6)
    fi
}

cleanup() {
    if [ "$TERMINAL_READY" -eq 1 ]; then
        [ -n "$STTY_STATE" ] && stty "$STTY_STATE" 2>/dev/null || true
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
    local cpu user nice system idle iowait irq softirq steal guest guest_nice

    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    CPU_IDLE=$((idle + iowait))
    CPU_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
}

init_cpu_sample() {
    read_cpu_times
    PREV_CPU_IDLE=$CPU_IDLE
    PREV_CPU_TOTAL=$CPU_TOTAL
}

get_cpu_usage() {
    local diff_idle
    local diff_total
    local usage=0

    read_cpu_times
    diff_idle=$((CPU_IDLE - PREV_CPU_IDLE))
    diff_total=$((CPU_TOTAL - PREV_CPU_TOTAL))

    if [ "$diff_total" -gt 0 ]; then
        usage=$((100 * (diff_total - diff_idle) / diff_total))
    fi

    PREV_CPU_IDLE=$CPU_IDLE
    PREV_CPU_TOTAL=$CPU_TOTAL
    printf '%s' "$usage"
}

get_memory_info() {
    free -h | awk '/Mem:/ {print $3, $2}'
}

get_memory_percent() {
    free -m | awk '/Mem:/ {if ($2 > 0) printf "%d", ($3 * 100 / $2); else printf "0"}'
}

get_disk_info() {
    df -hP / | awk 'NR==2 {print $3, $2, $5}'
}

get_temperature() {
    local value
    local temp

    if command -v sensors >/dev/null 2>&1; then
        value=$(sensors | awk '/Package id 0|Core 0|temp1/ {print $2; exit}')
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
    local cpu
    local mem_used
    local mem_total
    local mem_percent
    local disk_used
    local disk_total
    local disk_percent_text
    local disk_percent
    local temp
    local temp_percent
    local temp_display
    local -a rows

    cpu=$(get_cpu_usage)
    read -r mem_used mem_total <<< "$(get_memory_info)"
    mem_percent=$(get_memory_percent)
    read -r disk_used disk_total disk_percent_text <<< "$(get_disk_info)"
    disk_percent=${disk_percent_text%\%}
    temp=$(get_temperature)
    temp_percent=$(temperature_number "$temp")

    if [ "$temp" = "Not available" ]; then
        temp_display="Not available"
        temp_percent=0
    else
        temp_display="$temp"
    fi

    rows+=("$(metric_line "CPU" "${cpu}%" "$cpu" 60 85)")
    rows+=("$(metric_line "RAM" "${mem_used}/${mem_total} ${mem_percent}%" "$mem_percent" 75 90)")
    rows+=("$(metric_line "Disk" "${disk_used}/${disk_total} ${disk_percent}%" "$disk_percent" 75 90)")
    rows+=("$(metric_line "Temp" "$temp_display" "$temp_percent" 70 85)")
    rows+=("")
    rows+=("Uptime     $(uptime -p)")

    panel "$width" "System Usage" "${rows[@]}"
}

network_panel() {
    local width="$1"
    local gateway
    local line
    local -a rows
    local -a interfaces

    mapfile -t interfaces < <(ip -o -4 addr show up scope global 2>/dev/null | awk '{print $2 "  " $4}' | head -n 4)
    gateway=$(ip route 2>/dev/null | awk '/default/ {print $3 " via " $5; exit}')

    rows+=("Interfaces")
    if [ "${#interfaces[@]}" -eq 0 ]; then
        rows+=("  No active IPv4 interface")
    else
        for line in "${interfaces[@]}"; do
            rows+=("  $line")
        done
    fi

    rows+=("")
    rows+=("Gateway")
    rows+=("  ${gateway:-Not available}")

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

    rows+=("PID    COMMAND$(repeat_char " " "$((name_width - 7))")     CPU    MEM")

    while IFS= read -r line; do
        rows+=("$line")
    done < <(
        ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu 2>/dev/null |
            head -n "$limit" |
            awk -v nw="$name_width" '
                {
                    name = $2
                    if (length(name) > nw) {
                        name = substr(name, 1, nw - 1) "~"
                    }
                    printf "%5s  %-*s %6s %6s\n", $1, nw, name, $3 "%", $4 "%"
                }
            '
    )

    if [ "${#rows[@]}" -eq 1 ]; then
        rows+=("No process data available")
    fi

    panel "$width" "Top Processes" "${rows[@]}"
}

render_header() {
    local width="$1"
    local title="${BOLD}${CYAN}PC COMMAND CENTER${RESET}"
    local status

    status="$(whoami)@$(hostname) | $(date '+%Y-%m-%d %H:%M:%S') | $(uptime -p) | every ${REFRESH_INTERVAL}s"

    printf '%s\n' "$(center_ansi "$title" "$width")"
    printf '%s\n' "$(pad_ansi "$status" "$width")"
    printf '%s\n' "$(repeat_char "-" "$width")"
}

render_compact_header() {
    local width="$1"
    local host
    local title
    local status

    host="$(whoami)@$(hostname)"
    title="${BOLD}${CYAN}PC COMMAND CENTER${RESET}"
    status="$(date '+%H:%M:%S') | $(uptime -p) | every ${REFRESH_INTERVAL}s"

    print_fit_line "$width" "$title | $host | ${REFRESH_INTERVAL}s"
    print_fit_line "$width" "$status"
    printf '%s\n' "$(repeat_char "-" "$width")"
}

compact_system_rows() {
    local width="$1"
    local bar_width="$2"
    local cpu
    local mem_used
    local mem_total
    local mem_percent
    local disk_used
    local disk_total
    local disk_percent_text
    local disk_percent
    local temp
    local temp_percent
    local temp_display
    local left
    local right
    local half

    cpu=$(get_cpu_usage)
    read -r mem_used mem_total <<< "$(get_memory_info)"
    mem_percent=$(get_memory_percent)
    read -r disk_used disk_total disk_percent_text <<< "$(get_disk_info)"
    disk_percent=${disk_percent_text%\%}
    temp=$(get_temperature)
    temp_percent=$(temperature_number "$temp")

    if [ "$temp" = "Not available" ]; then
        temp_display="N/A"
        temp_percent=0
    else
        temp_display="$temp"
    fi

    half=$(((width - 2) / 2))
    left="$(compact_metric "CPU" "${cpu}%" "$cpu" 60 85 "$bar_width")"
    right="$(compact_metric "RAM" "${mem_used}/${mem_total} ${mem_percent}%" "$mem_percent" 75 90 "$bar_width")"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"

    left="$(compact_metric "DSK" "${disk_used}/${disk_total} ${disk_percent}%" "$disk_percent" 75 90 "$bar_width")"
    right="$(compact_metric "TMP" "$temp_display" "$temp_percent" 70 85 "$bar_width")"
    printf '%s  %s\n' "$(pad_ansi "$left" "$half")" "$(pad_ansi "$right" "$((width - half - 2))")"
}

compact_network_rows() {
    local width="$1"
    local rows="$2"
    local interface
    local gateway

    interface=$(ip -o -4 addr show up scope global 2>/dev/null | awk '{print $2 " " $4; exit}')
    gateway=$(ip route 2>/dev/null | awk '/default/ {print $3 " via " $5; exit}')

    interface=${interface:-No active IPv4}
    gateway=${gateway:-N/A}

    if [ "$rows" -le 1 ]; then
        print_fit_line "$width" "${BLUE}NET${RESET} $interface | GW $gateway"
    else
        print_fit_line "$width" "${BLUE}NET${RESET} $interface"
        print_fit_line "$width" "${BLUE}GW ${RESET} $gateway"
    fi
}

compact_process_rows() {
    local width="$1"
    local limit="$2"
    local name_width=$((width - 25))
    local line

    [ "$name_width" -lt 10 ] && name_width=10
    [ "$name_width" -gt 30 ] && name_width=30

    print_fit_line "$width" "${BLUE}Top Processes${RESET}"
    print_fit_line "$width" "PID    COMMAND$(repeat_char " " "$((name_width - 7))")    CPU   MEM"

    while IFS= read -r line; do
        print_fit_line "$width" "$line"
    done < <(
        ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu 2>/dev/null |
            head -n "$limit" |
            awk -v nw="$name_width" '
                {
                    name = $2
                    if (length(name) > nw) {
                        name = substr(name, 1, nw - 1) "~"
                    }
                    printf "%5s  %-*s %5s %5s\n", $1, nw, name, $3 "%", $4 "%"
                }
            '
    )
}

render_compact_dashboard() {
    local cols="$1"
    local lines="$2"
    local width="$cols"
    local process_limit=5
    local network_rows=2
    local bar_width=9

    [ "$width" -gt 88 ] && width=88
    [ "$width" -lt 60 ] && width=60

    if [ "$lines" -lt 24 ]; then
        process_limit=4
        network_rows=1
    fi

    if [ "$lines" -lt 21 ]; then
        process_limit=3
        network_rows=1
    fi

    if [ "$width" -ge 82 ]; then
        bar_width=10
    elif [ "$width" -lt 72 ]; then
        bar_width=7
    fi

    render_compact_header "$width"
    print_fit_line "$width" "${BLUE}System${RESET}"
    compact_system_rows "$width" "$bar_width"
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

    cols=$(tput_cmd cols)
    lines=$(tput_cmd lines)
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=${COLUMNS:-80}
    [[ "$lines" =~ ^[0-9]+$ ]] || lines=24

    width="$cols"
    [ "$width" -gt 120 ] && width=120
    [ "$width" -lt 36 ] && width=36

    if [ "$lines" -le 24 ]; then
        process_limit=5
    fi

    if [ "$LIVE_MODE" -eq 1 ]; then
        tput_cmd cup 0 0
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

render_dashboard() {
    local cols
    local lines

    cols=$(tput_cmd cols)
    lines=$(tput_cmd lines)
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=${COLUMNS:-80}
    [[ "$lines" =~ ^[0-9]+$ ]] || lines=${LINES:-24}

    if [ "$LIVE_MODE" -eq 1 ]; then
        tput_cmd cup 0 0
    fi

    if [ "$WIDE_MODE" -eq 1 ]; then
        render_wide_dashboard
    else
        render_compact_dashboard "$cols" "$lines"
        if [ "$LIVE_MODE" -eq 1 ]; then
            tput_cmd ed
        fi
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
            NEXT_DRAW=$(date +%s)
            ;;
        +|=)
            if [ "$REFRESH_INTERVAL" -gt 1 ]; then
                REFRESH_INTERVAL=$((REFRESH_INTERVAL - 1))
            fi
            render_dashboard
            NEXT_DRAW=$(date +%s)
            ;;
        -|_)
            REFRESH_INTERVAL=$((REFRESH_INTERVAL + 1))
            render_dashboard
            NEXT_DRAW=$(date +%s)
            ;;
    esac
}

run_live() {
    local key
    local now

    if [ ! -t 0 ] || [ ! -t 1 ]; then
        ONCE=1
        render_dashboard
        return
    fi

    LIVE_MODE=1
    trap cleanup EXIT
    trap 'exit 0' INT TERM
    setup_terminal
    render_dashboard
    NEXT_DRAW=$(($(date +%s) + REFRESH_INTERVAL))

    while true; do
        if read -rsn1 -t 0.1 key; then
            handle_key "$key"
        fi

        now=$(date +%s)
        if [ "$now" -ge "$NEXT_DRAW" ]; then
            render_dashboard
            NEXT_DRAW=$((now + REFRESH_INTERVAL))
        fi
    done
}

main() {
    parse_args "$@"
    setup_colors
    init_cpu_sample

    if [ "$ONCE" -eq 1 ]; then
        render_dashboard
    else
        run_live
    fi
}

main "$@"
