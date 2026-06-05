FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ansible \
    openssh-client \
    sshpass \
    python3 \
    iproute2 \
    iputils-ping \
    dnsutils \
    git \
    vim \
    less \
    && rm -rf /var/lib/apt/lists/*

# Quiet host-key prompts for the lab's throwaway hosts.
RUN mkdir -p /root/.ssh && \
    printf 'Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null\n' \
    > /root/.ssh/config && chmod 600 /root/.ssh/config

CMD ["sleep", "infinity"]
