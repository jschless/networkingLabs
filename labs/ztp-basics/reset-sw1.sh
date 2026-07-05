#!/usr/bin/env bash
# Factory-reset sw1 and reboot it into ZTP.
#
# Real-switch equivalent: 'write erase' + 'reload'. Here: remove
# startup-config and zerotouch-config from flash and restart the
# container — EOS boots with empty flash and enters ZTP mode on its
# management interface.
#
# Restarting a container destroys its containerlab data links (the veth
# pairs die with the netns), so after the reboot this script re-creates
# the two production links and re-runs the neighbours' setup. It then
# waits for ZTP to finish — zerotouch-config reappearing on flash is
# EOS's own "ZTP done" marker. While waiting it re-opens the switch's
# iptables policies each cycle: on Docker Desktop (macOS/Windows)
# kernels the EOS firewall agent's rule commit fails half-way, leaving
# default-DROP policies that would eat the ZTP HTTP fetch. Harmless
# no-op on a Linux host.
#
# If your provisioning service is broken (that's Task 6), ZTP loops
# forever and this script waits with it — that's your cue to go
# diagnose from ztp1's logs. Fix the service and the wait completes;
# Ctrl-C only stops the watcher, not the switch.

SW=clab-ztp-basics-sw1
ZTP1=clab-ztp-basics-ztp1
H1=clab-ztp-basics-h1

clab() {
  if command -v containerlab >/dev/null 2>&1; then
    containerlab "$@" || sudo containerlab "$@"
  else
    docker run --rm --privileged --network host --pid host \
      -v /var/run/docker.sock:/var/run/docker.sock -v /run/netns:/run/netns \
      ghcr.io/srl-labs/clab containerlab "$@"
  fi
}

echo "[reset] wiping ${SW} flash (startup-config + zerotouch-config)"
docker exec "$SW" bash -c 'rm -f /mnt/flash/startup-config /mnt/flash/zerotouch-config' || exit 1

echo "[reset] rebooting ${SW} into ZTP (EOS boot takes ~2-3 min)"
docker restart "$SW" >/dev/null

echo "[reset] re-plumbing data links (container restarts drop clab veths)"
clab tools veth create -a "$ZTP1:eth1" -b "$SW:eth1" >/dev/null 2>&1
clab tools veth create -a "$H1:eth1"   -b "$SW:eth2" >/dev/null 2>&1
docker exec "$ZTP1" bash /setup.sh
docker exec "$H1"   bash /setup.sh

echo -n "[reset] waiting for ZTP to complete "
for _ in $(seq 1 60); do
  docker exec "$SW" bash -c \
    'iptables -P INPUT ACCEPT; iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT;
     ip6tables -P INPUT ACCEPT; ip6tables -P OUTPUT ACCEPT; ip6tables -P FORWARD ACCEPT' \
    >/dev/null 2>&1
  if docker exec "$SW" bash -c 'test -f /mnt/flash/zerotouch-config' 2>/dev/null; then
    echo; echo "[reset] ZTP complete — sw1 provisioned itself."
    exit 0
  fi
  echo -n "."
  sleep 10
done

echo
echo "[reset] still not provisioned after 10 min — ZTP is looping."
echo "        Diagnose from ztp1: /var/log/dnsmasq.log and the http.server output."
exit 1
