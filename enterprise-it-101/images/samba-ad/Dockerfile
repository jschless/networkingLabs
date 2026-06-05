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
    iproute2 \
    iputils-ping \
    procps \
    chrony \
    ca-certificates \
    curl \
    openssl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# step CLI (Smallstep) — used in Lab 03 to bootstrap CA trust and issue
# certificates for LDAPS. Pinned for reproducibility; arch-detected so the
# image builds on both amd64 and arm64.
ARG STEP_VERSION=0.30.2
RUN arch="$(dpkg --print-architecture)" \
    && curl -fsSL "https://github.com/smallstep/cli/releases/download/v${STEP_VERSION}/step_linux_${arch}.tar.gz" \
       -o /tmp/step.tar.gz \
    && tar -xzf /tmp/step.tar.gz -C /tmp \
    && install -m 0755 "/tmp/step_linux_${arch}/bin/step" /usr/local/bin/step \
    && rm -rf /tmp/step.tar.gz "/tmp/step_linux_${arch}"

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY seed-domain.sh /usr/local/bin/seed-domain.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/seed-domain.sh

# supervisord program autostart flags are env-driven (see supervisord.conf).
# Lab 01 uses these defaults (samba stays down until the student provisions);
# Labs 02+ override them in the compose file.
ENV SAMBA_AUTOSTART=false \
    CHRONY_AUTOSTART=false

EXPOSE 53 88 135 139 389 445 464 636 3268 3269

CMD ["/usr/local/bin/entrypoint.sh"]
