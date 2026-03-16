system {
    config-management {
        commit-revisions 100
    }
    host-name gw-a
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
        address 192.168.1.1/24
        hw-id 52:54:00:01:00:01
    }
    ethernet eth2 {
        address 203.0.113.1/30
        hw-id 52:54:00:01:00:02
    }
    loopback lo {
    }
}

protocols {
    static {
        route 203.0.113.4/30 {
            next-hop 203.0.113.2 {
            }
        }
    }
}

service {
    ssh {
        port 22
    }
}
