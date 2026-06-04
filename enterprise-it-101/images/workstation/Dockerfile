FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    sssd \
    sssd-ad \
    realmd \
    krb5-user \
    ldap-utils \
    adcli \
    samba-common-bin \
    dnsutils \
    curl \
    vim \
    net-tools \
    iputils-ping \
    chrony \
    nfs-common \
    cifs-utils \
    iproute2 \
    procps \
    sudo \
    && rm -rf /var/lib/apt/lists/*

COPY krb5.conf /etc/krb5.conf

CMD ["sleep", "infinity"]
