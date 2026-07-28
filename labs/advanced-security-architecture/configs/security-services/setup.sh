#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.114.60.10/24 dev eth1
ip link set eth1 up
ip route replace default via 10.114.60.1
mkdir -p /var/log/asa /run/rsyslog
cat >/tmp/rsyslog.conf <<'EOF'
module(load="imuxsock")
module(load="imudp")
input(type="imudp" port="514")
template(name="LabLine" type="string" string="%timereported:::date-rfc3339% %hostname% %syslogtag%%msg%\n")
*.* action(type="omfile" file="/var/log/asa/central.log" template="LabLine")
EOF
rsyslogd -n -f /tmp/rsyslog.conf -i /run/rsyslog/rsyslogd.pid &
