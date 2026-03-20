system {
    config-management {
        commit-revisions 100
    }
    host-name core1
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
        address 203.0.113.2/30
        description "Toward enc-a"
    }
    ethernet eth2 {
        address 198.51.100.1/30
        description "Toward core2"
    }
    loopback lo {
    }
}

service {
    ssh {
        port 22
    }
}
