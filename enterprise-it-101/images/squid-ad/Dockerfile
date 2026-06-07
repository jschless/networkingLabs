FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# squid                         - the proxy + its Kerberos/LDAP auth helpers
#   (negotiate_kerberos_auth, ext_kerberos_ldap_group_acl live in /usr/lib/squid)
# samba-common-bin, winbind     - `net ads join` to get a machine keytab
# krb5-user, libsasl2-modules-gssapi-mit, ldap-utils
#                               - Kerberos client + GSSAPI LDAP for the group helper
RUN apt-get update && apt-get install -y --no-install-recommends \
    squid \
    krb5-user \
    samba-common-bin \
    samba-dsdb-modules \
    winbind \
    libsasl2-modules-gssapi-mit \
    ldap-utils \
    msktutil \
    dnsutils \
    curl \
    iproute2 \
    iputils-ping \
    procps \
    vim \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
