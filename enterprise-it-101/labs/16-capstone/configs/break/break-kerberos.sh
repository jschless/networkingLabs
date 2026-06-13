#!/bin/bash
# Part B, Break #2 — time/Kerberos. Run INSIDE dc1:
#   docker exec dc1 bash /break/break-kerberos.sh
#
# Pushes the domain controller's clock far into the future. Active Directory and
# Kerberos are exquisitely time-sensitive; with the DC convinced it is a year
# ahead, every account's password looks long expired, so authentication fails
# domain-wide with "Password expired / must be changed" — a symptom that looks
# like a password-policy problem but is really a clock problem.
#
# CONTAINER REALITY: every container shares the host's kernel clock, so the DC's
# real clock cannot be skewed in isolation. We fake it for the KDC process with
# libfaketime (LD_PRELOAD). The classic "Clock skew too great (KRB_AP_ERR_SKEW)"
# text is not reproducible here because krb5's skew check reads the time via the
# vDSO, which LD_PRELOAD cannot intercept — but the root cause and the fix (the
# DC's wall clock) are exactly the real-world lesson.
set -e
# libfaketime provides the clock fake. Install on demand if absent — by now the
# stack is up and dc1's DNS resolves, so apt can reach the package mirrors
# (it cannot during first-boot provisioning, before samba's DNS starts).
if ! dpkg -s libfaketime >/dev/null 2>&1; then
    echo "[break-kerberos] installing libfaketime..."
    apt-get update >/dev/null 2>&1 && apt-get install -y libfaketime >/dev/null 2>&1
fi
LIB=$(dpkg -L libfaketime 2>/dev/null | grep 'libfaketime\.so\.1$' | head -1)
if [ -z "$LIB" ]; then
    echo "[break-kerberos] libfaketime unavailable (needs internet on dc1)." >&2
    exit 1
fi
# A clearly-wrong far-future wall clock (well past the default 42-day password age).
date -u -d '+400 days' '+%Y-%m-%d %H:%M:%S' > /etc/faketimerc
echo "$LIB" > /etc/ld.so.preload
supervisorctl restart samba >/dev/null 2>&1 || true
echo "[break-kerberos] dc1 KDC clock faked to $(cat /etc/faketimerc) UTC."
echo "[break-kerberos] Symptom: domain authentication fails everywhere (password expired)."
