FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates coreutils dbus-daemon dbus-system-bus-common \
       cloud-image-utils e2fsprogs fio iperf3 iproute2 \
       iputils-ping jq kmod lsscsi multipath-tools netcat-openbsd \
       open-iscsi openssh-client procps qemu-system-x86 qemu-utils \
       sg3-utils targetcli-fb tcpdump util-linux \
    && rm -rf /var/lib/apt/lists/*

ADD --checksum=sha256:d1940f7d69d343355e183dff1e08a59852d32e7309baa7a4bad8365b11b005ac \
    https://cloud-images.ubuntu.com/noble/20260725/noble-server-cloudimg-amd64.img \
    /opt/storage/initiator-base.qcow2

RUN mkdir -p /opt/storage /run/multipath /var/lib/storage \
    && printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -eu' \
      'cleanup() {' \
      '  if [[ "${STORAGE_ROLE:-}" == "target" ]]; then' \
      '    targetcli /iscsi delete iqn.2026-07.lab.example:dc-storage >/dev/null 2>&1 || true' \
      '    targetcli /backstores/fileio delete storage-lun >/dev/null 2>&1 || true' \
      '    rm -f /var/lib/storage/lun.img' \
      '  fi' \
      '}' \
      'trap cleanup TERM INT EXIT' \
      'while :; do sleep 3600 & wait $!; done' \
      > /usr/local/bin/storage-entrypoint \
    && chmod 0755 /usr/local/bin/storage-entrypoint

CMD ["/usr/local/bin/storage-entrypoint"]
