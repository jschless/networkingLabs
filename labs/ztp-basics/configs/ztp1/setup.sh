#!/usr/bin/env bash
# ztp1 — provisioning server plumbing (addressing + templates only).
# Building the actual DHCP/HTTP service is the student's job.
# Idempotent: reset-sw1.sh re-runs this after re-plumbing the data
# links; template copies happen on the first run only so your edits
# survive.
set -e

# Server-segment address (the production-side link to sw1 Et1)
ip addr replace 10.0.99.10/24 dev eth1
ip link set eth1 up

# Return route to the user segment via the switch ZTP will provision
ip route replace 10.0.2.0/24 via 10.0.99.1

# Working copies — edit THESE inside the container:
#   /etc/dnsmasq.conf       (DHCP; skeleton with TODOs)
#   /var/www/startup-config (the config ZTP will serve; skeleton with TODOs)
if [ ! -f /var/run/ztp-setup-done ]; then
  cp /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
  mkdir -p /var/www
  cp /var/www.orig/* /var/www/
  touch /var/run/ztp-setup-done
fi
