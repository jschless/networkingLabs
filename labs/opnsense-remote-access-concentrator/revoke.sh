#!/usr/bin/env bash
set -euo pipefail
lab_dir=$(cd "$(dirname "$0")" && pwd)
exec "$lab_dir/peer-lifecycle.sh" revoke "$@"
