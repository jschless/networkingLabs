interfaces {
    ethernet eth0 {
        vrf MGMT
    }
    ethernet eth1 {
        address 10.10.1.2/30
        description "Source-facing trust boundary"
    }
    ethernet eth2 {
        address 10.10.2.1/30
        description "Internet-facing link"
    }
    loopback lo {
    }
}
protocols {
    static {
        route 10.0.0.10/32 {
            next-hop 10.10.1.1 {
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
    host-name edge
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
