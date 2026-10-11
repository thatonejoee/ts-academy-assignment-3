#!/usr/bin/env bash
# lint.sh - validate the repository.
#   1. Required files exist.
#   2. Every Bash script passes `bash -n` (syntax check).
#   3. If ShellCheck is installed, run it as an extra check.
# Exit 0 = everything passed, 1 = at least one check failed.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

failed=0

REQUIRED_FILES=(
    README.md
    app/app.sh
    scripts/lint.sh
    scripts/build.sh
    tests/test.sh
    .github/workflows/ci.yml
    Dockerfile
    compose.yaml
    .dockerignore
)

echo "== Required files =="
for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$f" ]; then
        echo "  [ OK ] $f"
    else
        echo "  [FAIL] missing: $f"
        failed=1
    fi
done

echo
echo "== Bash syntax (bash -n) =="
scripts=()
while IFS= read -r f; do
    scripts+=("$f")
done < <(find app scripts tests -type f -name '*.sh' 2>/dev/null | sort)

if [ "${#scripts[@]}" -eq 0 ]; then
    echo "  [FAIL] no shell scripts found"
    failed=1
fi

for f in "${scripts[@]}"; do
    if bash -n "$f"; then
        echo "  [ OK ] $f"
    else
        echo "  [FAIL] syntax error: $f"
        failed=1
    fi
done

echo
echo "== ShellCheck (optional) =="
if command -v shellcheck >/dev/null 2>&1; then
    if [ "${#scripts[@]}" -gt 0 ] && shellcheck "${scripts[@]}"; then
        echo "  [ OK ] shellcheck found no issues"
    elif [ "${#scripts[@]}" -gt 0 ]; then
        echo "  [FAIL] shellcheck reported issues"
        failed=1
    fi
else
    echo "  [SKIP] shellcheck is not installed"
fi

echo
if [ "$failed" -eq 0 ]; then
    echo "Lint passed"
    exit 0
fi
echo "Lint failed"
exit 1
