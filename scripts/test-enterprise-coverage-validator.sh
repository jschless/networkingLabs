#!/usr/bin/env bash
# Exercise the coverage validator's supported evidence failures.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-enterprise-coverage.py"
FIXTURES="$REPO_ROOT/tests/fixtures/enterprise-coverage"

python3 "$VALIDATOR" "$REPO_ROOT/docs/enterprise-coverage.yaml"
python3 "$VALIDATOR" "$FIXTURES/valid.yaml"

for fixture in invalid-level missing-lab level3-no-labs level3-no-check level5-no-scenarios; do
    if python3 "$VALIDATOR" "$FIXTURES/$fixture.yaml"; then
        echo "FAIL — negative fixture unexpectedly passed: $fixture" >&2
        exit 1
    fi
done

echo "OK — validator positive and negative fixtures behaved as expected"
