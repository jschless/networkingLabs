#!/bin/bash
# One-time node setup for the anycast resolver hosts (dns1/dns2).
# FRR itself is started by the image entrypoint before this runs.

# The DNS service (config bind-mounted at /etc/dnsmasq.conf; daemonizes)
dnsmasq

# Route health injection: watchdog owns the VIP on lo (see healthcheck.sh)
nohup sh /usr/local/bin/healthcheck.sh >>/var/log/healthcheck.log 2>&1 &

# Re-apply FRR config now that containerlab has created eth1
vtysh -b
