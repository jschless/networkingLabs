#!/usr/bin/env bash
set -euo pipefail

iface=$1
event=$2
case "$iface" in
  eth1) vlan=110 ;;
  eth3) vlan=130 ;;
  *) exit 0 ;;
esac

case "$event" in
  AP-STA-CONNECTED*)
    bridge vlan del dev "$iface" vid 99 2>/dev/null || true
    bridge vlan add dev "$iface" vid "$vlan" pvid untagged master
    nft delete element bridge wireless_auth blocked "{ \"$iface\" }" 2>/dev/null || true
    printf '%s role-authorized vlan=%s event=%s\n' "$iface" "$vlan" "$event" >> /var/log/policy-projection.log
    ;;
  AP-STA-DISCONNECTED*|CTRL-EVENT-EAP-FAILURE*)
    bridge vlan del dev "$iface" vid "$vlan" 2>/dev/null || true
    bridge vlan add dev "$iface" vid 99 pvid untagged master
    nft add element bridge wireless_auth blocked "{ \"$iface\" }" 2>/dev/null || true
    printf '%s role-revoked event=%s\n' "$iface" "$event" >> /var/log/policy-projection.log
    ;;
esac
