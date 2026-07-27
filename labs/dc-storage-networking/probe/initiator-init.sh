#!/usr/bin/env bash
set -euxo pipefail

mkdir -p /run/storage-vm
STORAGE_MTU=9000
MULTIPATH_PATH=/etc/multipath.conf
if [[ "${STORAGE_LAB_MODE:-probe}" == "practice" ]]; then
  STORAGE_MTU=1500
  MULTIPATH_PATH=/opt/storage/multipath.solution.conf
fi
for spec in "a eth1 $STORAGE_MTU" "b eth2 $STORAGE_MTU" "mgmt eth3 1500"; do
  read -r name iface mtu <<<"$spec"
  ip link add "br-$name" type bridge
  ip link set "$iface" mtu "$mtu"
  ip link set "$iface" master "br-$name"
  ip link set "$iface" up
  ip tuntap add "tap-$name" mode tap
  ip link set "tap-$name" mtu "$mtu"
  ip link set "tap-$name" master "br-$name"
  ip link set "tap-$name" up
  ip link set "br-$name" mtu "$mtu"
  ip link set "br-$name" up
done
ip addr add 10.111.30.254/24 dev br-mgmt

ssh-keygen -q -t ed25519 -N "" -f /run/storage-vm/id_ed25519
PUBKEY="$(cat /run/storage-vm/id_ed25519.pub)"
{
  printf '%s\n' '#cloud-config'
  printf '%s\n' 'hostname: initiator1' 'manage_etc_hosts: true'
  printf '%s\n' 'users:' '  - name: storage' '    groups: [sudo]' '    sudo: ALL=(ALL) NOPASSWD:ALL'
  printf '    ssh_authorized_keys: [%s]\n' "\"$PUBKEY\""
  printf '%s\n' 'ssh_pwauth: false' 'disable_root: true'
  printf '%s\n' 'write_files:'
  printf '%s\n' "  - path: $MULTIPATH_PATH" '    permissions: "0644"' '    content: |'
  sed 's/^/      /' /etc/multipath.conf
  printf '%s\n' '  - path: /etc/iscsi/initiatorname.iscsi' '    permissions: "0600"'
  printf '%s\n' '    content: |' '      InitiatorName=iqn.2026-07.lab.example:initiator1'
  printf '%s\n' 'runcmd:'
  printf '%s\n' '  - [systemctl, restart, iscsid]' '  - [systemctl, restart, multipathd]'
  if [[ "${STORAGE_LAB_MODE:-probe}" == "practice" ]]; then
    printf '%s\n' \
      '  - [ip, rule, add, prohibit, from, 10.111.10.0/24, to, 10.111.30.0/24, priority, "100"]' \
      '  - [ip, rule, add, prohibit, from, 10.111.20.0/24, to, 10.111.30.0/24, priority, "101"]'
  fi
  printf '%s\n' '  - [touch, /run/storage-vm-ready]'
} >/run/storage-vm/user-data

printf '%s\n' 'instance-id: dc-storage-initiator' 'local-hostname: initiator1' \
  >/run/storage-vm/meta-data
{
  printf '%s\n' 'version: 2' 'ethernets:'
  printf '%s\n' '  mgmt0:' '    match: {macaddress: "52:54:00:11:30:10"}' \
    '    set-name: mgmt0' '    addresses: [10.111.30.10/24]'
  printf '%s\n' '  storagea:' '    match: {macaddress: "52:54:00:11:10:10"}' \
    '    set-name: storagea' '    addresses: [10.111.10.10/24]' "    mtu: $STORAGE_MTU"
  printf '%s\n' '  storageb:' '    match: {macaddress: "52:54:00:11:20:10"}' \
    '    set-name: storageb' '    addresses: [10.111.20.10/24]' "    mtu: $STORAGE_MTU"
} >/run/storage-vm/network-config

cloud-localds --network-config=/run/storage-vm/network-config \
  /run/storage-vm/seed.img /run/storage-vm/user-data /run/storage-vm/meta-data
cp --reflink=auto /opt/storage/initiator-base.qcow2 /run/storage-vm/initiator.qcow2
qemu-img resize /run/storage-vm/initiator.qcow2 4G

qemu-system-x86_64 \
  -name dc-storage-initiator -enable-kvm -cpu host -smp 1 -m 768 \
  -drive file=/run/storage-vm/initiator.qcow2,if=virtio,format=qcow2 \
  -drive file=/run/storage-vm/seed.img,if=virtio,format=raw,readonly=on \
  -netdev tap,id=mgmt,ifname=tap-mgmt,script=no,downscript=no \
  -device virtio-net-pci,netdev=mgmt,mac=52:54:00:11:30:10 \
  -netdev tap,id=storagea,ifname=tap-a,script=no,downscript=no \
  -device virtio-net-pci,netdev=storagea,mac=52:54:00:11:10:10 \
  -netdev tap,id=storageb,ifname=tap-b,script=no,downscript=no \
  -device virtio-net-pci,netdev=storageb,mac=52:54:00:11:20:10 \
  -display none -serial file:/run/storage-vm/console.log \
  -daemonize -pidfile /run/storage-vm/qemu.pid

for _ in $(seq 1 90); do
  if ssh -i /run/storage-vm/id_ed25519 -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o ConnectTimeout=1 \
    storage@10.111.30.10 test -e /run/storage-vm-ready; then
    exit 0
  fi
  sleep 1
done
tail -100 /run/storage-vm/console.log
exit 1
