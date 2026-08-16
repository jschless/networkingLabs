interfaces {
    ethernet eth0 {
        vrf MGMT
    }
    ethernet eth1 {
        address 10.1.1.2/30
        description "Voice source"
    }
    ethernet eth2 {
        address 10.1.2.2/30
        description "Video source"
    }
    ethernet eth3 {
        address 10.1.3.2/30
        description "Bulk-data source"
    }
    ethernet eth4 {
        address 10.2.0.1/30
        description "Shaped WAN egress"
    }
    loopback lo {
    }
}
qos {
    interface eth4 {
        egress QOS-BASELINE
    }
    policy {
        rate-control QOS-BASELINE {
            bandwidth 2mbit
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
    host-name router
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
