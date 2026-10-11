#!/usr/bin/env bash
# build.sh - build the Docker image and run smoke tests against it.
# Usage: scripts/build.sh
# Environment: IMAGE (default: devops-tool)
# Exit 0 = built and all smoke tests passed, 1 = a step failed.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-devops-tool}"
failed=0

if ! command -v docker >/dev/null 2>&1; then
    echo "docker is not installed" >&2
    exit 1
fi

echo "== Building image '$IMAGE' =="
if ! docker build -t "$IMAGE" "$ROOT"; then
    echo "[FAIL] docker build failed" >&2
    exit 1
fi
echo "[ OK ] image built"

# smoke <name> <expected-exit-code> <args...>
smoke() {
    local name="$1" want="$2" out rc
    shift 2
    out="$(docker run --rm "$IMAGE" "$@" 2>&1)"
    rc=$?
    if [ "$rc" -eq "$want" ]; then
        echo "[ OK ] $name (exit $rc)"
    else
        echo "[FAIL] $name (expected exit $want, got $rc)"
        while IFS= read -r line; do
            echo "       $line"
        done <<< "$out"
        failed=1
    fi
}

echo
echo "== Smoke tests =="
smoke "help"                     0 help
smoke "system-info"              0 system-info
smoke "invalid command"          2 not-a-command
smoke "check-host without host"  2 check-host
smoke "check-host localhost"     0 check-host localhost
smoke "check-port bad port"      2 check-port localhost 99999

echo
if [ "$failed" -eq 0 ]; then
    echo "Build and smoke tests passed"
    exit 0
fi
echo "Build or smoke tests failed"
exit 1
