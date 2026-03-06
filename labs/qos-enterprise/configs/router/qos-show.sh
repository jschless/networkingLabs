#!/bin/bash
# qos-show.sh — Display QoS statistics for eth4
#
# Key counters to watch:
#   Sent bytes/packets — traffic that passed through this class
#   dropped            — packets dropped by this class's qdisc (congestion)
#   overlimits         — times the class exceeded its rate (triggered borrowing)
#   requeues           — packets re-queued after send failure (usually 0)
#
# For GRED (video class 1:20):
#   early              — packets dropped by RED before queue was full (AQM working)
#   pdrop              — packets dropped because queue was completely full

ETH=eth4

echo "========================================================================"
echo "  QoS Statistics for $ETH"
echo "========================================================================"
echo ""

echo "--- Root qdisc ---"
tc -s qdisc show dev $ETH
echo ""

echo "--- HTB Class Hierarchy and Stats ---"
tc -s class show dev $ETH
echo ""

echo "--- Filter Rules (DSCP -> Class mappings) ---"
tc -s filter show dev $ETH
echo ""

echo "========================================================================"
echo "  Quick reference:"
echo "    1:10 = Voice  (EF  DSCP46)  800kbps guaranteed"
echo "    1:20 = Video  (AF41 DSCP34) 600kbps guaranteed + WRED"
echo "    1:30 = Data   (BE  DSCP 0)  600kbps guaranteed + SFQ"
echo "========================================================================"
