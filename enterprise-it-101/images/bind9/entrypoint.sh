#!/bin/bash
# ============================================================
# bind9:local entrypoint.
#
# Runs named in the foreground (PID 1) so the container stays up and its
# logs are visible via `docker logs dns1`. The config starts bare (a
# recursion-off resolver); the student edits /etc/bind/*.conf in place and
# applies changes with `rndc reconfig` — no container restart needed.
# ============================================================
set -e

# Validate the baseline config but never block startup on it.
named-checkconf || true

exec /usr/sbin/named -g -c /etc/bind/named.conf -u bind
