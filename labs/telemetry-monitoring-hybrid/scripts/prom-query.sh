#!/bin/bash
set -euo pipefail

query="${1:-up}"

curl -s "http://127.0.0.1:9090/api/v1/query?query=${query}"
