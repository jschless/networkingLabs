FROM debian@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iperf3=3.12-1+deb12u2 \
        iproute2=6.1.0-3 \
        iputils-ping=3:20221126-1+deb12u1 \
        tcpdump=4.99.3-1 \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
