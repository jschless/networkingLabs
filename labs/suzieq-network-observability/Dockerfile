# 3.9, not newer: suzieq 0.24 caps its python requirement below 3.10, so on
# newer interpreters pip backtracks to ancient suzieq releases whose pinned
# pandas (1.1.4) has no py3.10+/arm64 wheels and fails to build from source.
FROM python:3.9-slim

# gcc/libc6-dev: psutil (pinned by suzieq) has no arm64 cp39 wheel and must
# compile from source on Apple Silicon.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir suzieq

RUN mkdir -p /root/.ssh && \
    printf 'StrictHostKeyChecking no\nUserKnownHostsFile /dev/null\n' > /root/.ssh/config

CMD ["sleep", "infinity"]
