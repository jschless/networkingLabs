#!/usr/bin/env python3
"""
Minimal RPKI RTR Server (RFC 8210, protocol version 1) for lab use.

Serves a fixed set of ROAs to FRR's rpkid via the RTR protocol.
This is intentionally minimal: it handles Reset Query and Serial Query,
responds with Cache Response + IPv4 Prefix records + End of Data.

ROA database:
  10.100.0.0/24  maxLen 24  origin AS65100  (isp1 announcement will be VALID)
  10.200.0.0/24  maxLen 24  origin AS65200  (not announced in lab → prefix stays NOT-FOUND)

The hijacker announces 10.100.0.0/24 with origin AS65999, which does not match
the ROA for that prefix → INVALID on the receiving edge router.
"""

import socket
import struct
import threading

# ---------------------------------------------------------------------------
# ROA database: list of (prefix_bytes, prefix_len, max_len, asn)
# ---------------------------------------------------------------------------
ROAS = [
    (socket.inet_aton('10.100.0.0'), 24, 24, 65100),
    (socket.inet_aton('10.200.0.0'), 24, 24, 65200),
]

SESSION_ID = 0x0001
SERIAL     = 1
RTR_VER    = 1   # RFC 8210 version 1

# ---------------------------------------------------------------------------
# PDU builders
# ---------------------------------------------------------------------------

def pdu_cache_response():
    """Type 3 — Cache Response (8 bytes)."""
    return struct.pack('!BBHI', RTR_VER, 3, SESSION_ID, 8)


def pdu_ipv4_prefix(prefix_bytes, prefix_len, max_len, asn, flags=1):
    """Type 4 — IPv4 Prefix (20 bytes).

    flags=1 → announce; flags=0 → withdraw
    """
    length = 20
    hdr  = struct.pack('!BBHI', RTR_VER, 4, 0, length)
    body = struct.pack('!BBBB', flags, prefix_len, max_len, 0)
    return hdr + body + prefix_bytes + struct.pack('!I', asn)


def pdu_end_of_data():
    """Type 7 — End of Data v1 (24 bytes, includes timing fields)."""
    length          = 24
    refresh_interval = 3600   # seconds
    retry_interval   = 600
    expire_interval  = 7200
    hdr  = struct.pack('!BBHI', RTR_VER, 7, SESSION_ID, length)
    body = struct.pack('!IIII', SERIAL, refresh_interval, retry_interval, expire_interval)
    return hdr + body


def send_full_cache(conn):
    """Send a complete cache snapshot to the client."""
    response = pdu_cache_response()
    for prefix_bytes, prefix_len, max_len, asn in ROAS:
        response += pdu_ipv4_prefix(prefix_bytes, prefix_len, max_len, asn)
    response += pdu_end_of_data()
    conn.sendall(response)


# ---------------------------------------------------------------------------
# Client handler
# ---------------------------------------------------------------------------

def handle_client(conn, addr):
    print(f"[rtr] client connected: {addr}", flush=True)
    try:
        while True:
            # Read the fixed 8-byte RTR header
            header = b''
            while len(header) < 8:
                chunk = conn.recv(8 - len(header))
                if not chunk:
                    return
                header += chunk

            ver, pdu_type, session_or_code, length = struct.unpack('!BBHI', header)

            # Consume any remaining bytes in this PDU
            remaining = length - 8
            if remaining > 0:
                conn.recv(remaining)

            print(f"[rtr] received PDU type={pdu_type} ver={ver} len={length}", flush=True)

            if pdu_type in (1, 2):
                # Type 1 = Serial Query, Type 2 = Reset Query
                # Respond with the full cache in both cases (we have no diff support)
                print(f"[rtr] sending full cache ({len(ROAS)} ROAs)", flush=True)
                send_full_cache(conn)

    except (ConnectionResetError, BrokenPipeError, OSError) as e:
        print(f"[rtr] client {addr} disconnected: {e}", flush=True)
    except Exception as e:
        print(f"[rtr] error handling {addr}: {e}", flush=True)
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', 3323))
    server.listen(5)
    print("[rtr] RTR server listening on 0.0.0.0:3323", flush=True)
    print(f"[rtr] serving {len(ROAS)} ROAs:", flush=True)
    for pb, pl, ml, asn in ROAS:
        print(f"[rtr]   {socket.inet_ntoa(pb)}/{pl}  maxLen={ml}  AS{asn}", flush=True)

    while True:
        conn, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(conn, addr), daemon=True)
        t.start()


if __name__ == '__main__':
    main()
