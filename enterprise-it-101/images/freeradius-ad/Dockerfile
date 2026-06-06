FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# freeradius + ldap/utils  - the RADIUS server, its LDAP module, radtest/radclient
# samba + winbind          - `net ads join` + ntlm_auth, so MSCHAPv2 (PEAP inner)
#                            can be validated against AD
# krb5-user, ldap-utils    - Kerberos client + LDAP CLI for checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    freeradius \
    freeradius-ldap \
    freeradius-utils \
    eapoltest \
    samba \
    winbind \
    libnss-winbind \
    libpam-winbind \
    krb5-user \
    ldap-utils \
    dnsutils \
    curl \
    iproute2 \
    iputils-ping \
    procps \
    vim \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
