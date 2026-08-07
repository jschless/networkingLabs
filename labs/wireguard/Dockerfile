FROM debian@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

# Package candidates recorded 2026-08-06. Review the pin and rebuild the lab
# during the next monthly image refresh; do not update a single package without
# repeating the clean deploy/break/repair validation in VALIDATION.md.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash=5.2.15-2+b13 \
    iproute2=6.1.0-3 \
    iputils-ping=3:20221126-1+deb12u1 \
    tcpdump=4.99.3-1 \
    wireguard-tools=1.0.20210914-1+b1 \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
