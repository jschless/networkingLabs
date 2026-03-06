#!/bin/bash
# qos-apply.sh — Apply 3-class HTB QoS on router eth4 (WAN-side bottleneck, 2Mbps)
#
# Traffic class hierarchy:
#
#   root (1:) HTB
#   └── 1:1  total bandwidth 2Mbps
#       ├── 1:10  Voice  EF   DSCP 46  800kbps guaranteed  prio 1  leaf: prio
#       ├── 1:20  Video  AF41 DSCP 34  600kbps guaranteed  prio 2  leaf: GRED (WRED)
#       └── 1:30  Data   BE   DSCP  0  600kbps guaranteed  prio 3  leaf: SFQ  (default)
#
# DSCP encoding in IP ToS byte (DSCP shifted left 2 bits):
#   DSCP 46 (EF)   = 0b101110xx -> ToS 0xb8
#   DSCP 34 (AF41) = 0b100010xx -> ToS 0x88
#   DSCP  0 (BE)   = 0b000000xx -> ToS 0x00

ETH=eth4
RATE=2mbit

echo "[QoS] Applying HTB QoS on $ETH (total $RATE)..."

# Remove any existing root qdisc
tc qdisc del dev $ETH root 2>/dev/null || true

# ── Root qdisc ──────────────────────────────────────────────────────────────
# HTB with default class 1:30 (unclassified traffic falls into data/BE)
tc qdisc add dev $ETH root handle 1: htb default 30

# ── Root class (aggregate bandwidth ceiling) ─────────────────────────────────
tc class add dev $ETH parent 1: classid 1:1 htb rate $RATE burst 15k

# ── Leaf classes ─────────────────────────────────────────────────────────────
# Voice: 800kbps guaranteed, can borrow up to full 2Mbps, highest priority
tc class add dev $ETH parent 1:1 classid 1:10 htb \
    rate 800kbit ceil $RATE burst 15k prio 1

# Video: 600kbps guaranteed, can borrow up to full 2Mbps, medium priority
tc class add dev $ETH parent 1:1 classid 1:20 htb \
    rate 600kbit ceil $RATE burst 15k prio 2

# Data/BE: 600kbps guaranteed, can borrow all remaining, lowest priority
tc class add dev $ETH parent 1:1 classid 1:30 htb \
    rate 600kbit ceil $RATE burst 15k prio 3

# ── Leaf qdiscs ──────────────────────────────────────────────────────────────
# Voice: single-band prio qdisc (strict FIFO, minimal latency)
tc qdisc add dev $ETH parent 1:10 handle 10: prio bands 1

# Video: GRED (Generic RED / WRED) — begin dropping before queue fills
#   limit=50000B  total buffer
#   min=5000B     start probabilistic drops here
#   max=40000B    drop all above this
#   avpkt=1000B   average packet size (for smoothing)
#   burst=10      smoothing window (burst packets before avg kicks in)
#   probability=0.1  max drop probability (10%)
tc qdisc add dev $ETH parent 1:20 handle 20: gred setup DPs 1 default 0 grio
tc qdisc change dev $ETH handle 20: gred \
    limit 50000 min 5000 max 40000 avpkt 1000 burst 10 probability 0.1 \
    DP 0 prio 0

# Data: SFQ (Stochastic Fair Queuing) — fair among competing flows
tc qdisc add dev $ETH parent 1:30 handle 30: sfq perturb 10

# ── Classifiers (DSCP → class mapping) ──────────────────────────────────────
# Match ToS field using u32 filter: mask 0xfc keeps only the DSCP bits
# (lower 2 bits of ToS are ECN and are ignored for classification)

# DSCP 46 (EF) → Voice class 1:10
tc filter add dev $ETH parent 1: protocol ip prio 10 \
    u32 match ip dsfield 0xb8 0xfc classid 1:10

# DSCP 34 (AF41) → Video class 1:20
tc filter add dev $ETH parent 1: protocol ip prio 20 \
    u32 match ip dsfield 0x88 0xfc classid 1:20

# All other traffic → Data class 1:30 (also the HTB default)
# (explicit catch-all is optional since htb default 30 handles unmatched,
#  but this makes the filter table self-documenting)
tc filter add dev $ETH parent 1: protocol ip prio 30 \
    u32 match ip dsfield 0x00 0xfc classid 1:30

echo ""
echo "[QoS] HTB applied on $ETH — total bandwidth: $RATE"
echo "[QoS] Classes:"
echo "        1:10  Voice  EF   DSCP46  800kbps guaranteed  (leaf: prio)"
echo "        1:20  Video  AF41 DSCP34  600kbps guaranteed  (leaf: GRED/WRED)"
echo "        1:30  Data   BE   DSCP 0  600kbps guaranteed  (leaf: SFQ, default)"
echo ""
echo "[QoS] View stats:  bash /qos-show.sh"
echo "[QoS] Remove QoS:  bash /qos-remove.sh"
