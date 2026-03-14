#!/bin/bash
set -e

mkdir -p /var/log/remote

cat > /etc/rsyslog.conf <<'EOF'
module(load="imudp")
input(type="imudp" port="514")

$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
$RepeatedMsgReduction off

template(name="PerHost" type="string" string="/var/log/remote/%HOSTNAME%.log")
*.* ?PerHost
& stop
EOF

rsyslogd

echo "[syslog] Listening on UDP/514 and writing to /var/log/remote/*.log"
