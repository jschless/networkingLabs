#!/usr/bin/env python3
"""Small deterministic RFC 8210 RTR cache for this isolated lab."""
import socket
import struct
import threading

# (network, prefix length, max length, origin AS).  198.51.100.66/32 is
# deliberately outside the valid content ROA and is used only for RTBH practice.
ROAS = [
    ("203.0.113.0", 24, 24, 65001),
    ("198.51.100.0", 24, 24, 65002),
]

def cache():
    result = struct.pack("!BBHI", 1, 3, 1, 8)
    for network, plen, maximum, asn in ROAS:
        result += struct.pack("!BBHI", 1, 4, 0, 20)
        result += struct.pack("!BBBB", 1, plen, maximum, 0)
        result += socket.inet_aton(network) + struct.pack("!I", asn)
    return result + struct.pack("!BBHIIIII", 1, 7, 1, 24, 1, 3600, 600, 7200)

def client(conn, address):
    try:
        while True:
            header = conn.recv(8)
            if not header:
                return
            _, pdu_type, _, length = struct.unpack("!BBHI", header)
            remaining = length - 8
            while remaining:
                remaining -= len(conn.recv(remaining))
            if pdu_type in (1, 2):
                conn.sendall(cache())
    finally:
        conn.close()

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("0.0.0.0", 3323))
server.listen(5)
while True:
    connection, address = server.accept()
    threading.Thread(target=client, args=(connection, address), daemon=True).start()
