#!/bin/bash
# qos-remove.sh — Tear down all QoS on eth4
tc qdisc del dev eth4 root 2>/dev/null \
    && echo "[QoS] Removed root qdisc from eth4 — interface is now unthrottled." \
    || echo "[QoS] Nothing to remove (no root qdisc found on eth4)."
