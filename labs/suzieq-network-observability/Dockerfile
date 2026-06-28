FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir suzieq

RUN mkdir -p /root/.ssh && \
    printf 'StrictHostKeyChecking no\nUserKnownHostsFile /dev/null\n' > /root/.ssh/config

CMD ["sleep", "infinity"]
