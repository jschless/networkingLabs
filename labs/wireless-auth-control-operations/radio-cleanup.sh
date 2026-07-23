#!/usr/bin/env bash
set -euo pipefail
if lsmod | grep -q '^mac80211_hwsim '; then
  echo "mac80211_hwsim is loaded; it was not loaded by this fallback, so do not unload shared host state." >&2
  exit 1
fi
if iw phy | grep -q 'hwsim'; then
  echo "unexpected hwsim PHY present; investigate host state without broad cleanup" >&2
  exit 1
fi
echo "No fallback-created virtual radio artifacts found."
