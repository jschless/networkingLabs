#!/usr/bin/env bash
# Wrap one interactive node session with util-linux script(1).
#
# Usage: capture.sh <attempt-dir> <node> -- <interactive-command...>
# The command normally is `docker exec -it clab-... bash` or `... Cli`.
set -euo pipefail

[[ $# -ge 4 && "$3" == "--" ]] || {
    echo "Usage: $0 <attempt-dir> <node> -- <interactive-command...>" >&2
    exit 2
}

attempt_dir="$1"
node="$2"
shift 3
mkdir -p "$attempt_dir/sessions"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
safe_node="${node//[^A-Za-z0-9_.-]/_}"
base="$attempt_dir/sessions/${stamp}-${safe_node}"

command="$(printf ' %q' "$@")"
command="${command:1}"
script --quiet --flush --log-out "${base}.typescript" --log-timing "${base}.timing" \
    --command "$command"

printf 'Transcript: %s\nTiming: %s\n' "${base}.typescript" "${base}.timing"
