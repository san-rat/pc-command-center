#!/bin/bash

# Ubuntu Command Center
# A lightweight terminal dashboard for Ubuntu/Linux systems

get_cpu_usage() {
    read cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    prev_idle=$((idle + iowait))
    prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

    sleep 1

    read cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    idle=$((idle + iowait))
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))

    diff_idle=$((idle - prev_idle))
    diff_total=$((total - prev_total))

    cpu_usage=$((100 * (diff_total - diff_idle) / diff_total))
    echo "$cpu_usage%"
}

get_temperature() {
    if command -v sensors >/dev/null 2>&1; then
        sensors | grep -m 1 -E "Package id 0|Core 0|temp1" | awk '{print $2}'
    elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo "$((temp / 1000))°C"
    else
        echo "Not available"
    fi
}

get_network_info() {
    ip -o -4 addr show up scope global | awk '{print $2 " - " $4}' | head -n 3
}

while true
do
    clear

    echo "=================================================="
    echo "              UBUNTU COMMAND CENTER               "
    echo "=================================================="
    echo

    echo "User:        $(whoami)"
    echo "Hostname:    $(hostname)"
    echo "Date/Time:   $(date)"
    echo "Uptime:      $(uptime -p)"
    echo

    echo "---------------- SYSTEM USAGE --------------------"
    echo "CPU Usage:   $(get_cpu_usage)"
    echo "RAM Usage:"
    free -h | awk '/Mem:/ {print "Used: " $3 " / Total: " $2 " | Free: " $4}'
    echo

    echo "Disk Usage:"
    df -h / | awk 'NR==2 {print "Used: " $3 " / Total: " $2 " | Available: " $4 " | Usage: " $5}'
    echo

    echo "Temperature: $(get_temperature)"
    echo

    echo "---------------- NETWORK INFO --------------------"
    network_info=$(get_network_info)

    if [ -z "$network_info" ]; then
        echo "No active network connection found"
    else
        echo "$network_info"
    fi

    echo
    echo "Default Gateway:"
    ip route | awk '/default/ {print $3 " via " $5}' | head -n 1
    echo

    echo "---------------- TOP PROCESSES -------------------"
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 8

    echo
    echo "=================================================="
    echo "Press CTRL + C to exit"
    echo "Refreshes every 5 seconds"
    echo "=================================================="

    sleep 5
done
