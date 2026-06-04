FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    samba \
    samba-dsdb-modules \
    samba-vfs-modules \
    krb5-user \
    krb5-kdc \
    winbind \
    libnss-winbind \
    libpam-winbind \
    supervisor \
    dnsutils \
    ldap-utils \
    net-tools \
    iputils-ping \
    procps \
    vim \
    && rm -rf /var/lib/apt/lists/*

COPY supervisord.conf /etc/supervisor/supervisord.conf

EXPOSE 53 88 135 139 389 445 464 636 3268 3269

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
