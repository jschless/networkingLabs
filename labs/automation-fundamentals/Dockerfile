FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq iputils-ping \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir requests pyyaml pygnmi

CMD ["sleep", "infinity"]
