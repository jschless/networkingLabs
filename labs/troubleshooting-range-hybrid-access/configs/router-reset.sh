#!/bin/sh
set -eu

flush_link() {
    ip link set "$1" down
    ip addr flush dev "$1"
    ip link set "$1" up
}

reset_filter() {
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    ip6tables -F
    ip6tables -t mangle -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    ip6tables -P INPUT ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
}

node="$(hostname)"
reset_filter

case "$node" in
    campus-edge)
        for link in eth1 eth2 eth3; do flush_link "$link"; done
        ip addr add 10.70.10.1/24 dev eth1
        ip -6 addr add 2001:db8:70:10::1/64 dev eth1 nodad
        ip addr add 10.70.12.1/30 dev eth2
        ip -6 addr add 2001:db8:70:12::1/64 dev eth2 nodad
        ip addr add 10.70.13.1/30 dev eth3
        ip -6 addr add 2001:db8:70:13::1/64 dev eth3 nodad
        ip route replace 10.70.0.0/16 via 10.70.12.2 metric 10
        ip route replace 10.70.0.0/16 via 10.70.13.2 metric 100
        ip -6 route replace 2001:db8:70::/48 via 2001:db8:70:12::2 metric 10
        ip -6 route replace 2001:db8:70::/48 via 2001:db8:70:13::2 metric 100
        ;;
    wan-a)
        for link in eth1 eth2; do flush_link "$link"; done
        ip addr add 10.70.12.2/30 dev eth1
        ip -6 addr add 2001:db8:70:12::2/64 dev eth1 nodad
        ip addr add 10.70.24.1/30 dev eth2
        ip -6 addr add 2001:db8:70:24::1/64 dev eth2 nodad
        ip route replace 10.70.10.0/24 via 10.70.12.1
        ip route replace 10.70.0.0/16 via 10.70.24.2
        ip -6 route replace 2001:db8:70:10::/64 via 2001:db8:70:12::1
        ip -6 route replace 2001:db8:70::/48 via 2001:db8:70:24::2
        ;;
    wan-b)
        for link in eth1 eth2; do flush_link "$link"; done
        ip addr add 10.70.13.2/30 dev eth1
        ip -6 addr add 2001:db8:70:13::2/64 dev eth1 nodad
        ip addr add 10.70.25.1/30 dev eth2
        ip -6 addr add 2001:db8:70:25::1/64 dev eth2 nodad
        ip route replace 10.70.10.0/24 via 10.70.13.1
        ip route replace 10.70.0.0/16 via 10.70.25.2
        ip -6 route replace 2001:db8:70:10::/64 via 2001:db8:70:13::1
        ip -6 route replace 2001:db8:70::/48 via 2001:db8:70:25::2
        ;;
    cloud-edge)
        for link in eth1 eth2 eth3 eth4 eth5 eth6; do flush_link "$link"; done
        ip addr add 10.70.24.2/30 dev eth1
        ip -6 addr add 2001:db8:70:24::2/64 dev eth1 nodad
        ip addr add 10.70.25.2/30 dev eth2
        ip -6 addr add 2001:db8:70:25::2/64 dev eth2 nodad
        ip addr add 10.70.30.1/24 dev eth3
        ip -6 addr add 2001:db8:70:30::1/64 dev eth3 nodad
        ip addr add 10.70.41.1/24 dev eth4
        ip -6 addr add 2001:db8:70:41::1/64 dev eth4 nodad
        ip addr add 10.70.42.1/24 dev eth5
        ip -6 addr add 2001:db8:70:42::1/64 dev eth5 nodad
        ip addr add 10.70.53.1/24 dev eth6
        ip -6 addr add 2001:db8:70:53::1/64 dev eth6 nodad
        ip route replace 10.70.10.0/24 via 10.70.24.1 metric 10
        ip route replace 10.70.10.0/24 via 10.70.25.1 metric 100
        ip -6 route replace 2001:db8:70:10::/64 via 2001:db8:70:24::1 metric 10
        ip -6 route replace 2001:db8:70:10::/64 via 2001:db8:70:25::1 metric 100

        iptables -P FORWARD DROP
        ip6tables -P FORWARD DROP
        iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        ip6tables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -A FORWARD -p icmp -j ACCEPT
        ip6tables -A FORWARD -p ipv6-icmp -j ACCEPT
        for proto in udp tcp; do
            iptables -A FORWARD -s 10.70.10.0/24 -d 10.70.53.53 -p "$proto" --dport 53 -j ACCEPT
            ip6tables -A FORWARD -s 2001:db8:70:10::/64 -d 2001:db8:70:53::53 -p "$proto" --dport 53 -j ACCEPT
        done
        iptables -A FORWARD -s 10.70.10.0/24 -d 10.70.30.30 -p tcp --dport 9443 -j ACCEPT
        ip6tables -A FORWARD -s 2001:db8:70:10::/64 -d 2001:db8:70:30::30 -p tcp --dport 9443 -j ACCEPT
        for destination in 10.70.41.40 10.70.42.40; do
            iptables -A FORWARD -s 10.70.10.0/24 -d "$destination" -p tcp -m multiport --dports 8080,8081 -j ACCEPT
        done
        for destination in 2001:db8:70:41::40 2001:db8:70:42::40; do
            ip6tables -A FORWARD -s 2001:db8:70:10::/64 -d "$destination" -p tcp -m multiport --dports 8080,8081 -j ACCEPT
        done
        iptables -A FORWARD -s 10.70.30.30 -d 10.70.41.40 -p tcp --dport 8443 -j ACCEPT
        ip6tables -A FORWARD -s 2001:db8:70:30::30 -d 2001:db8:70:41::40 -p tcp --dport 8443 -j ACCEPT
        iptables -A FORWARD -s 10.70.10.0/24 -d 10.70.41.40 -p tcp --dport 8443 -j REJECT
        ip6tables -A FORWARD -s 2001:db8:70:10::/64 -d 2001:db8:70:41::40 -p tcp --dport 8443 -j REJECT
        ;;
    *)
        echo "unknown router role: $node" >&2
        exit 1
        ;;
esac

ip neigh flush all >/dev/null 2>&1 || true
ip -6 neigh flush all >/dev/null 2>&1 || true
