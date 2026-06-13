#!/bin/bash
# Backup server entrypoint: bring up sshd in the foreground.
# Host keys are generated on first boot and persist only for the life of
# the container (they are not lab state worth a volume).
set -e

mkdir -p /run/sshd
ssh-keygen -A

exec /usr/sbin/sshd -D -e
