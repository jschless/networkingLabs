#!/bin/bash
# Part B, Break #2 — time/Kerberos repair. Run INSIDE dc1:
#   docker exec dc1 bash /break/fix-kerberos.sh
set -e
rm -f /etc/ld.so.preload /etc/faketimerc
supervisorctl restart samba >/dev/null 2>&1 || true
echo "[fix-kerberos] dc1 clock override removed; KDC back on real time: $(date -u)."
echo "[fix-kerberos] Give samba ~10s, then re-test kinit."
