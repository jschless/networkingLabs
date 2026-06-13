# Lab 15 (Backup & Recovery) backup server: BorgBackup repository host.
#
# Runs sshd with a dedicated `borg` service account (password P@ssw0rd1,
# like every other lab credential). Service nodes PUSH backups to it over
# SSH; it also mounts other containers' data volumes so volume-level
# backups of agent-less containers (ca1) can be taken locally.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    borgbackup \
    openssh-server \
    cron \
    vim \
    less \
    procps \
    iproute2 \
    iputils-ping \
    dnsutils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Dedicated backup account: repos live under /srv/backups, owned by borg.
# Password auth is enabled so the student can ssh-copy-id their way to
# key-based trust (that's a task, not pre-built plumbing).
RUN useradd -m -s /bin/bash borg \
    && echo 'borg:P@ssw0rd1' | chpasswd \
    && mkdir -p /srv/backups \
    && chown borg:borg /srv/backups

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

CMD ["/usr/local/bin/entrypoint.sh"]
