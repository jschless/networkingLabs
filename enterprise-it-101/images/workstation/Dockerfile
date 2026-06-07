FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    sssd \
    sssd-ad \
    sssd-tools \
    realmd \
    krb5-user \
    ldap-utils \
    adcli \
    samba-common-bin \
    smbclient \
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
    tcpdump \
    sudo \
    faketime \
    openssl \
    oathtool \
    ca-certificates \
    isc-dhcp-client \
    openssh-server \
    swaks \
    libnet-ssleay-perl \
    && rm -rf /var/lib/apt/lists/*

# step CLI (Smallstep) — Lab 03 bootstraps CA trust and issues/verifies
# certificates from the workstation. Pinned + arch-detected (amd64/arm64).
ARG STEP_VERSION=0.30.2
RUN arch="$(dpkg --print-architecture)" \
    && curl -fsSL "https://github.com/smallstep/cli/releases/download/v${STEP_VERSION}/step_linux_${arch}.tar.gz" \
       -o /tmp/step.tar.gz \
    && tar -xzf /tmp/step.tar.gz -C /tmp \
    && install -m 0755 "/tmp/step_linux_${arch}/bin/step" /usr/local/bin/step \
    && rm -rf /tmp/step.tar.gz "/tmp/step_linux_${arch}"

COPY krb5.conf /etc/krb5.conf
COPY ldap.conf /etc/ldap/ldap.conf

CMD ["sleep", "infinity"]
