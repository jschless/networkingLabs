interfaces {
    ethernet eth1 {
        description "MACsec source link"
    }
    ethernet eth2 {
        address 198.51.100.1/30
        description "Plain Ethernet baseline"
    }
    macsec macsec0 {
        address 192.0.2.1/30
        description "Protected Ethernet link to r2"
        source-interface eth1
        security {
            cipher gcm-aes-128
            encrypt
            mka {
                cak "0123456789abcdef0123456789abcdef"
                ckn "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
            }
            replay-window "0"
        }
    }
}
service {
    ssh {
        listen-address "0.0.0.0"
    }
}
system {
    config-management {
        commit-revisions "100"
    }
    host-name r1
    login {
        user admin {
            authentication {
                encrypted-password "$6$rounds=656000$N1LbfkrIwbaOqpjl$INxsQ0iMFS7lXflarFCXJcM/AB8MscGFBQ4yBY7H9fpfJrTKuV8tZBBilfev/BllqpJb78cDAnKnpeKO7ibUp1"
            }
        }
    }
    syslog {
        local {
            facility all {
                level "info"
            }
        }
    }
}

// vyos-config-version: "bgp@6:broadcast-relay@1:cluster@2:config-management@1:conntrack@6:conntrack-sync@2:container@3:dhcp-relay@2:dhcp-server@11:dhcpv6-server@6:dns-dynamic@4:dns-forwarding@4:firewall@20:flow-accounting@3:https@7:ids@2:interfaces@34:ipoe-server@4:ipsec@14:isis@3:l2tp@9:lldp@3:mdns@1:monitoring@2:nat@8:nat66@3:nhrp@1:ntp@3:openconnect@3:openvpn@5:ospf@2:pim@1:policy@9:pppoe-server@12:pptp@5:qos@3:quagga@12:reverse-proxy@3:rip@1:rpki@2:salt@1:snmp@3:ssh@3:sstp@6:system@31:vpp@6:vrf@4:vrrp@4:vyos-accel-ppp@2:wanloadbalance@4:webproxy@2"
