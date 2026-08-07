#!/bin/sh
set -eu

ip link set eth1 up
ip address replace 172.16.0.2/24 dev eth1
ip link set eth2 up
ip address replace 172.16.1.1/30 dev eth2

mkdir -p /var/log/remote /var/log/netflow

cat >/etc/rsyslog.conf <<'EOF'
module(load="imudp")
input(type="imudp" port="514")

template(name="RemoteLine" type="string"
         string="%timegenerated% %fromhost-ip% %hostname% %msg%\n")
if ($fromhost-ip == "172.16.0.1") then {
  action(type="omfile" file="/var/log/remote/router.log" template="RemoteLine")
  stop
}
EOF

if ! pgrep -x rsyslogd >/dev/null 2>&1; then
    rsyslogd
fi

if [ -s /run/nfcapd.pid ] && kill -0 "$(cat /run/nfcapd.pid)" 2>/dev/null; then
    :
else
    rm -f /run/nfcapd.pid
    nohup nfcapd -w /var/log/netflow -p 2055 -t 5 -P /run/nfcapd.pid \
        >/var/log/nfcapd.log 2>&1 &
fi

echo "[management] SNMP poller, UDP/514 syslog, and UDP/2055 NetFlow collector ready"
