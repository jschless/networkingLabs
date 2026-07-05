#!/bin/sh
# client — the "user" that reaches Kubernetes LoadBalancer services by
# their VIP, routed through the ToR.
ip addr replace 172.16.9.10/24 dev eth1
# replace, not add: containerlab already installed a mgmt default route;
# reach the rack + service VIPs via the ToR.
ip route replace 10.1.0.0/24 via 172.16.9.1
ip route replace 198.51.100.0/24 via 172.16.9.1
echo "[client] 172.16.9.10/24, rack + service VIPs via tor 172.16.9.1"
