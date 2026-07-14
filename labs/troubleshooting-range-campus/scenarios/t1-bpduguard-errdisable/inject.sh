#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus

docker exec "$P-rogue1" python3 -c 'import socket,struct; dst=bytes.fromhex("0180c2000000"); src=bytes.fromhex("020000000001"); llc=b"\x42\x42\x03"; bpdu=b"\x00\x00\x02\x02\x00"+bytes.fromhex("8000020000000001")+struct.pack("!I",0)+bytes.fromhex("8000020000000001")+struct.pack("!H",0x8001)+struct.pack("!HHHH",0,20*256,2*256,15*256); frame=dst+src+struct.pack("!H",len(llc+bpdu))+llc+bpdu; s=socket.socket(socket.AF_PACKET,socket.SOCK_RAW); s.bind(("eth1",0)); s.send(frame.ljust(60,b"\x00"))'
for _ in $(seq 1 10); do
    status="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show interfaces status' || true)"
    [[ "$status" == *'Et5'*errdisabled* ]] && { echo 'Ticket symptom is active.'; exit 0; }
    sleep 1
done
echo 'ERROR: protected edge did not enter errdisabled state' >&2
exit 1
