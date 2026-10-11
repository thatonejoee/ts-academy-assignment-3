#!/usr/bin/env bash
# app.sh - small Bash application used for the CI/CD practical.
#
# Usage:
#   app.sh system-info
#   app.sh check-host <host>
#   app.sh check-port <host> <port>
#   app.sh help
#
# Exit codes:
#   0  success
#   1  operational failure (host does not resolve, port is closed)
#   2  invalid command or input
set -u

PROG="$(basename "$0")"
CONNECT_TIMEOUT=3

usage() {
    cat << EOF
Usage: $PROG <command> [arguments]

Commands:
  system-info              Show system information
  check-host <host>        Resolve a hostname or IP address
  check-port <host> <port> Check TCP connectivity to host:port (1-65535)
  help                     Show this help message

Exit codes:
  0  success
  1  operational failure
  2  invalid command or input
EOF
}

err() {
    echo "Error: $*" >&2
}

invalid() {
    err "$*"
    echo "Run '$PROG help' for usage." >&2
    exit 2
}

row() {
    printf '%-18s %s\n' "$1:" "$2"
}

# --- validation -------------------------------------------------------------

valid_host() {
    local h="$1"
    [ -n "$h" ] && [ "${#h}" -le 253 ] || return 1
    # Hostname or IPv4: letters, digits, dots, hyphens; no leading/trailing
    # hyphen or dot, and no empty labels.
    if [[ "$h" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] && [[ "$h" != *..* ]]; then
        return 0
    fi
    # IPv6: hex digits, colons and dots.
    if [[ "$h" == *:* ]] && [[ "$h" =~ ^[0-9A-Fa-f:.]+$ ]]; then
        return 0
    fi
    return 1
}

# validate_port <value>: prints the port as a plain integer, or returns 1.
validate_port() {
    local p="$1"
    [[ "$p" =~ ^[0-9]{1,5}$ ]] || return 1
    p=$((10#$p))
    [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || return 1
    echo "$p"
}

# --- helpers (portable across Alpine/busybox and Debian/Ubuntu) ---------------

get_os() {
    if [ -r /etc/os-release ]; then
        # shellcheck source=/dev/null
        ( . /etc/os-release; echo "${PRETTY_NAME:-${NAME:-Unknown}}" )
    else
        uname -s
    fi
}

get_uptime() {
    local secs d h m
    if [ -r /proc/uptime ]; then
        secs="$(cut -d. -f1 /proc/uptime)"
        d=$((secs / 86400))
        h=$(((secs % 86400) / 3600))
        m=$(((secs % 3600) / 60))
        echo "${d}d ${h}h ${m}m"
    else
        uptime
    fi
}

get_cpu() {
    local model cores
    model="$(grep -m1 -i 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')"
    [ -z "$model" ] && model="$(uname -m)"
    cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '?')"
    echo "$model ($cores cores)"
}

get_memory() {
    awk '
        /^MemTotal:/     {t=$2}
        /^MemAvailable:/ {a=$2}
        END {
            if (t > 0) {
                printf "Total %d MiB, Available %d MiB, Used %d MiB\n", t/1024, a/1024, (t-a)/1024
            } else {
                print "Unknown"
            }
        }' /proc/meminfo 2>/dev/null || echo "Unknown"
}

resolve_host() {
    getent ahosts "$1" 2>/dev/null | awk 'NR==1 {print $1}'
}

# tcp_open <host> <port>: succeeds if a TCP connection can be opened.
tcp_open() {
    # The single quotes are intentional: $1 and $2 belong to the inner bash,
    # which receives host and port as arguments (no command injection).
    # shellcheck disable=SC2016
    timeout "$CONNECT_TIMEOUT" bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$1" "$2" 2>/dev/null
}

# --- commands -----------------------------------------------------------------

cmd_system_info() {
    [ $# -eq 0 ] || invalid "'system-info' takes no arguments (got: $*)"
    echo "================================="
    echo "       SYSTEM INFORMATION"
    echo "================================="
    row "Hostname"     "$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname)"
    row "User"         "$(id -un 2>/dev/null || echo unknown)"
    row "Date/Time"    "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    row "OS"           "$(get_os)"
    row "Kernel"       "$(uname -r)"
    row "Architecture" "$(uname -m)"
    row "Uptime"       "$(get_uptime)"
    row "CPU"          "$(get_cpu)"
    row "Memory"       "$(get_memory)"
    echo "================================="
    return 0
}

cmd_check_host() {
    [ $# -ge 1 ] || invalid "'check-host' requires a host argument"
    [ $# -le 1 ] || invalid "'check-host' takes exactly one host (got: $*)"
    local host="$1"
    valid_host "$host" || invalid "'$host' is not a valid hostname or IP address"

    local resolved
    resolved="$(resolve_host "$host")"
    if [ -z "$resolved" ]; then
        echo "FAIL: could not resolve '$host'"
        return 1
    fi
    echo "OK: $host resolves to $resolved"
    return 0
}

cmd_check_port() {
    [ $# -ge 1 ] || invalid "'check-port' requires a host and a port"
    [ $# -ge 2 ] || invalid "'check-port' requires a port after the host"
    [ $# -le 2 ] || invalid "'check-port' takes exactly a host and a port (got: $*)"
    local host="$1" port_arg="$2" port
    valid_host "$host" || invalid "'$host' is not a valid hostname or IP address"
    if ! [[ "$port_arg" =~ ^[0-9]+$ ]]; then
        invalid "port '$port_arg' is not a number"
    fi
    port="$(validate_port "$port_arg")" || invalid "port must be between 1 and 65535 (got '$port_arg')"

    if [ -z "$(resolve_host "$host")" ]; then
        echo "FAIL: could not resolve '$host'"
        return 1
    fi
    if tcp_open "$host" "$port"; then
        echo "OK: TCP port $port is open on $host"
        return 0
    fi
    echo "FAIL: TCP port $port is closed or unreachable on $host"
    return 1
}

# --- dispatch -----------------------------------------------------------------

if [ $# -eq 0 ]; then
    usage >&2
    exit 2
fi

command="$1"
shift

case "$command" in
    system-info) cmd_system_info "$@" ;;
    check-host)  cmd_check_host "$@" ;;
    check-port)  cmd_check_port "$@" ;;
    help|-h|--help)
        usage
        ;;
    *)
        invalid "unknown command '$command'"
        ;;
esac
exit $?
