system {
    config-management {
        commit-revisions 100
    }
    host-name red-a
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

interfaces {
    ethernet eth1 {
        address 10.10.10.1/24
    }
    ethernet eth2 {
        address 10.255.0.1/30
    }
    loopback lo {
    }
}

protocols {
    static {
        route 10.255.0.4/30 {
            next-hop 10.255.0.2 {
            }
        }
    }
}

service {
    ssh {
        port 22
    }
}
