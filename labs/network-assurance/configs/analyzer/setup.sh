#!/bin/bash
# analyzer — receives SPAN traffic mirrored from r2:eth1 via management
set -e

ip link set eth1 up
ip addr add 192.168.99.2/30 dev eth1

echo "[analyzer] Ready — receives SPAN frames from r2:eth1 via management:eth4"
echo ""
echo "  Watch SPAN traffic:  tcpdump -i eth1 -n"
echo "  Filter by protocol:  tcpdump -i eth1 -n icmp"
echo "  Save to pcap:        tcpdump -i eth1 -w /tmp/span.pcap"
