#!/usr/bin/env bash
# Deterministic local substitute for bgpq4. It reads only checked-in synthetic
# objects and emits a reviewable FRR prefix-list; it never contacts an IRR.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "usage: $0 <AS-number> <prefix-list-name>" >&2
  exit 2
fi
input="$(dirname "$0")/irr/$1.txt"
[[ -f "$input" ]] || { echo "no local object for $1" >&2; exit 2; }
sequence=10
while read -r prefix; do
  printf 'ip prefix-list %s seq %s permit %s\n' "$2" "$sequence" "$prefix"
  sequence=$((sequence + 10))
done < <(awk '/^route:[[:space:]]/ { print $2 }' "$input")
printf 'ip prefix-list %s seq %s deny 0.0.0.0/0 le 32\n' "$2" "$sequence"
