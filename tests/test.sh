#!/usr/bin/env bash
# tests/test.sh - tests for app/app.sh.
# Usage: tests/test.sh
# Environment: APP overrides the path to the application under test.
# Exit 0 = all tests passed, 1 = at least one test failed.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${APP:-$ROOT/app/app.sh}"

PASS=0
FAIL=0
OUT=""
RC=0
SERVER_PID=""

# Called through the EXIT trap below.
# shellcheck disable=SC2317,SC2329
cleanup() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null
    fi
}
trap cleanup EXIT

if [ ! -x "$APP" ]; then
    echo "Application not found or not executable: $APP" >&2
    exit 1
fi

# capture <args...>: run the app, store combined output in OUT and exit code in RC
capture() {
    OUT="$("$APP" "$@" 2>&1)"
    RC=$?
}

pass() { PASS=$((PASS + 1)); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  [FAIL] $1"; }

# check <name> <expected-exit> [pattern]: compare the last capture
check() {
    local name="$1" want="$2" pattern="${3:-}"
    if [ "$RC" -ne "$want" ]; then
        fail "$name (expected exit $want, got $RC)"
        return
    fi
    if [ -n "$pattern" ] && ! printf '%s' "$OUT" | grep -qi -- "$pattern"; then
        fail "$name (output did not match '$pattern')"
        return
    fi
    pass "$name"
}

echo "Testing: $APP"
echo

echo "help"
capture help
check "help exits 0 and shows usage" 0 "usage"

echo "system-info"
capture system-info
check "system-info exits 0 and shows hostname" 0 "hostname"
check "system-info shows kernel" 0 "kernel"

echo "invalid input"
capture not-a-command
check "unknown command exits 2" 2 "unknown command"
capture
check "no command exits 2" 2 "usage"
capture system-info extra
check "system-info rejects extra arguments" 2

echo "check-host"
capture check-host
check "missing host exits 2" 2 "requires a host"
capture check-host 'bad_host!'
check "malformed host exits 2" 2 "not a valid"
capture check-host localhost
check "valid host (localhost) exits 0" 0 "ok"
capture check-host nonexistent.invalid
check "unresolvable host exits 1" 1 "fail"

echo "check-port"
capture check-port localhost
check "missing port exits 2" 2 "requires a port"
capture check-port
check "missing host and port exits 2" 2
capture check-port localhost abc
check "non-numeric port exits 2" 2 "not a number"
capture check-port localhost 0
check "port 0 exits 2" 2 "between 1 and 65535"
capture check-port localhost 65536
check "port 65536 exits 2" 2 "between 1 and 65535"
capture check-port localhost 70000
check "port 70000 exits 2" 2 "between 1 and 65535"
capture check-port localhost 1
check "closed port exits 1" 1 "closed"

# An open port is only tested when python3 is available to start a listener.
if command -v python3 >/dev/null 2>&1; then
    port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
    python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 &
    SERVER_PID=$!
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
        sleep 0.3
    done
    capture check-port 127.0.0.1 "$port"
    check "open port exits 0" 0 "open"
else
    echo "  [SKIP] open port test (python3 not available)"
fi

echo
echo "Passed: $PASS   Failed: $FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
