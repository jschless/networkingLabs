interfaces {
    ethernet eth0 {
        vrf MGMT
    }
    ethernet eth1 {
        address 192.168.2.1/24
        description "Site B LAN"
        mtu 1500
    }
    ethernet eth2 {
        address 203.0.113.6/30
        description "Provider-facing transport"
        mtu 1500
    }
    loopback lo {
    }
    tunnel tun0 {
        address 172.16.0.2/30
        encapsulation gre
        remote 203.0.113.1
        source-address 203.0.113.6
    }
}
protocols {
    static {
        route 192.168.1.0/24 {
            next-hop 172.16.0.1 {
            }
        }
        route 203.0.113.0/30 {
            next-hop 203.0.113.5 {
            }
        }
    }
}
service {
    ssh {
        port 22
    }
}
system {
    config-management {
        commit-revisions 100
    }
    host-name edge-b
    login {
        user admin {
            authentication {
                encrypted-password "$6$rounds=656000$tPZiQf9IZMRCQ4av$8/7f7L33sL6Vxq4McCP0ofvP5aQ4J7G5iwr4IkBYk2gLQ4puN8LJ7w0c0i7f4QbEXfN9u1Qw0c6A5Q7E.0sZf."
                plaintext-password ""
            }
        }
    }
    syslog {
        local {
            facility all {
                level info
            }
            facility local7 {
                level debug
            }
        }
    }
}
vrf {
    name MGMT {
        protocols {
            static {
                route 0.0.0.0/0 {
                    next-hop 172.20.20.1 {
                    }
                }
            }
        }
        table 100
    }
}
