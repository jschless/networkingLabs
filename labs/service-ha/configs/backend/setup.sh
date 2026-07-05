#!/bin/bash
# backend — the protected service. Reached only through the firewall pair.
ip addr replace 10.10.20.10/24 dev eth1
ip link set eth1 up
# default via the INSIDE VIP (10.10.20.1) so return traffic goes back
# through the *same* active firewall (symmetric path — a stateful firewall
# drops asymmetric flows).
ip route replace default via 10.10.20.1
# a long-lived TCP service for the failover test (echo server, port 9999)
ncat -l -k -p 9999 --exec /bin/cat >/var/log/echo.log 2>&1 &
echo "[backend] 10.10.20.10/24, default via VIP 10.10.20.1, echo server :9999"
