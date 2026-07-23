#!/usr/bin/env bash
set -euo pipefail
echo "Unsupported on this host: PROBE.md records that mac80211_hwsim cannot be loaded non-interactively."
echo "This fallback intentionally creates no virtual PHY, namespace radio, or WLAN interface."
exit 3
