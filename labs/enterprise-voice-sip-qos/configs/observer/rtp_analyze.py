#!/usr/bin/env python3
"""Report RTP packet, sequence-gap, and RFC 3550 jitter data from a pcap."""

from __future__ import annotations

import argparse
import ipaddress
import json
import struct
from collections import defaultdict
from pathlib import Path


def packets(path: Path):
    data = path.read_bytes()
    if len(data) < 24:
        raise ValueError("pcap is too short")
    magic = data[:4]
    if magic == b"\xd4\xc3\xb2\xa1":
        endian, scale = "<", 1_000_000
    elif magic == b"\xa1\xb2\xc3\xd4":
        endian, scale = ">", 1_000_000
    elif magic == b"\x4d\x3c\xb2\xa1":
        endian, scale = "<", 1_000_000_000
    else:
        raise ValueError(f"unsupported pcap magic {magic.hex()}")
    _, _, _, _, _, _, linktype = struct.unpack(endian + "IHHIIII", data[:24])
    if linktype != 1:
        raise ValueError(f"expected Ethernet pcap (DLT 1), got {linktype}")
    offset = 24
    while offset + 16 <= len(data):
        sec, fraction, captured, _ = struct.unpack(endian + "IIII", data[offset : offset + 16])
        offset += 16
        frame = data[offset : offset + captured]
        offset += captured
        yield sec + fraction / scale, frame


def analyze(path: Path):
    streams = defaultdict(lambda: {"packets": 0, "gaps": 0, "jitter": 0.0})
    state = {}
    for arrival, frame in packets(path):
        if len(frame) < 14 or frame[12:14] != b"\x08\x00":
            continue
        ip = frame[14:]
        if len(ip) < 20 or ip[9] != 17:
            continue
        ihl = (ip[0] & 0x0F) * 4
        if len(ip) < ihl + 20:
            continue
        src, dst = ipaddress.ip_address(ip[12:16]), ipaddress.ip_address(ip[16:20])
        udp = ip[ihl:]
        sport, dport = struct.unpack("!HH", udp[:4])
        rtp = udp[8:]
        if len(rtp) < 12 or rtp[0] >> 6 != 2 or (rtp[1] & 0x7F) not in (0, 8):
            continue
        seq, timestamp, ssrc = struct.unpack("!HII", rtp[2:12])
        key = f"{src}:{sport}>{dst}:{dport}/ssrc={ssrc:08x}"
        item = streams[key]
        item["packets"] += 1
        previous = state.get(key)
        transit = arrival * 8000 - timestamp
        if previous:
            expected = (previous["seq"] + 1) & 0xFFFF
            if seq != expected:
                item["gaps"] += (seq - expected) & 0xFFFF
            delta = abs(transit - previous["transit"])
            item["jitter"] += (delta - item["jitter"]) / 16
        state[key] = {"seq": seq, "transit": transit}
    for item in streams.values():
        total = item["packets"] + item["gaps"]
        item["loss_pct"] = round(100 * item["gaps"] / total, 4) if total else 0
        item["jitter_ms"] = round(item.pop("jitter") / 8, 3)
    return dict(streams)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pcap", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = analyze(args.pcap)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        for key, value in sorted(result.items()):
            print(
                f"{key} packets={value['packets']} gaps={value['gaps']} "
                f"loss={value['loss_pct']:.4f}% jitter={value['jitter_ms']:.3f}ms"
            )
    return 0 if result else 1


if __name__ == "__main__":
    raise SystemExit(main())
