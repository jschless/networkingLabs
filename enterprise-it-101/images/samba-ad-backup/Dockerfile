# Lab 15 (Backup & Recovery) domain controller: samba-ad plus the Borg
# CLIENT tooling. Backups are PUSH-mode — dc1 runs `borg create` against
# an ssh:// repo on backup1 — so the DC needs borg, an ssh client, and
# cron for the scheduled-backup task. Nothing is pre-configured: the SSH
# trust, the repo, and the backup script are all student work.
#
# Build AFTER samba-ad:local (eit.sh build does this in order).
FROM samba-ad:local

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    borgbackup \
    openssh-client \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Run cron under supervisord so scheduled backups survive however the
# student gets here (base image has no [include] section, so append one).
COPY cron-supervisor.conf /etc/supervisor/conf.d/cron.conf
RUN printf '\n[include]\nfiles = /etc/supervisor/conf.d/*.conf\n' \
    >> /etc/supervisor/supervisord.conf
