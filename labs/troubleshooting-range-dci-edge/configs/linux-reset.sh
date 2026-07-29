#!/bin/sh
set -eu

flush_link() {
    ip link set "$1" down 2>/dev/null || true
    ip addr flush dev "$1" 2>/dev/null || true
    tc qdisc del dev "$1" root 2>/dev/null || true
    ip link set "$1" up
}

reset_filter() {
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
}

stop_apps() {
    pkill -f /opt/range/app_server.py 2>/dev/null || true
}

start_app() {
    python3 /opt/range/app_server.py --port "$1" --body "$2" \
        >/tmp/range-app-"$1".log 2>&1 &
}

node="$(hostname)"
reset_filter
stop_apps

case "$node" in
    a-prod)
        flush_link eth1
        ip addr add 172.16.10.10/24 dev eth1
        ip route replace default via 172.16.10.1 dev eth1
        start_app 8080 site-a-prod-ok
        ;;
    b-prod)
        flush_link eth1
        ip addr add 172.17.10.10/24 dev eth1
        ip route replace default via 172.17.10.1 dev eth1
        start_app 8080 site-b-prod-ok
        ;;
    shared-app)
        flush_link eth1
        ip addr add 172.31.10.10/24 dev eth1
        ip route replace default via 172.31.10.1 dev eth1
        start_app 8080 shared-app-ok
        ;;
    edge-client)
        flush_link eth1
        ip addr add 10.80.10.10/24 dev eth1
        ip route replace default via 10.80.10.1 dev eth1
        ;;
    internet-client)
        flush_link eth1
        flush_link eth2
        ip addr add 192.0.2.10/24 dev eth1
        ip addr add 203.0.113.10/24 dev eth2
        ip route replace 10.90.20.0/24 via 192.0.2.1 dev eth1
        ;;
    inspection)
        flush_link eth1
        flush_link eth2
        ip addr add 192.0.2.1/24 dev eth1
        ip addr add 10.90.20.1/24 dev eth2
        iptables -P FORWARD DROP
        iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -A FORWARD -s 192.0.2.10 -d 10.90.20.20 \
            -p tcp --dport 8080 -j ACCEPT
        ;;
    public-origin)
        flush_link eth1
        flush_link eth2
        ip addr add 10.90.20.20/24 dev eth1
        ip addr add 203.0.113.20/24 dev eth2
        ip route replace default via 10.90.20.1 dev eth1
        iptables -I INPUT 1 -i eth2 -s 203.0.113.10 -p tcp --dport 8443 \
            -m comment --comment range-direct-origin-deny -j REJECT
        start_app 8080 inspected-origin-ok
        start_app 8443 protected-origin-ok
        ;;
    storage-init)
        for link in eth1 eth2; do
            flush_link "$link"
            ip link set "$link" mtu 9000
        done
        ip addr add 10.92.10.10/24 dev eth1
        ip addr add 10.92.20.10/24 dev eth2
        ;;
    storage-target)
        for link in eth1 eth2; do
            flush_link "$link"
            ip link set "$link" mtu 9000
        done
        ip addr add 10.92.10.20/24 dev eth1
        ip addr add 10.92.20.20/24 dev eth2
        start_app 3260 storage-session-ready
        ;;
    storage-path-a|storage-path-b)
        ip link del br-storage 2>/dev/null || true
        for link in eth1 eth2; do
            flush_link "$link"
            ip link set "$link" mtu 9000
        done
        ip link add br-storage type bridge
        ip link set br-storage mtu 9000 up
        ip link set eth1 master br-storage
        ip link set eth2 master br-storage
        ;;
    *)
        echo "unknown Linux range role: $node" >&2
        exit 1
        ;;
esac

ip neigh flush all >/dev/null 2>&1 || true
