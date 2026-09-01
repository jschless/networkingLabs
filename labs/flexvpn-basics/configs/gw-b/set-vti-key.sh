#!/usr/bin/env bash
set -euo pipefail

case ${1:-} in
    healthy) key=1 ;;
    fault) key=9 ;;
    *) echo "usage: $0 healthy|fault" >&2; exit 2 ;;
esac

ip tunnel change vti0 mode vti local 203.0.113.6 remote 203.0.113.1 key "$key"
ip link set vti0 up
