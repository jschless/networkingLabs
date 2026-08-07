# Anycast resolver node: FRR (routing on the host) is the base; add the
# DNS service (dnsmasq) and dig (bind-tools — used by the health-check
# watchdog and for local verification). bash for the setup script.
FROM frr-lab:local

RUN apk add --no-cache \
      bash=5.1.16-r2 \
      bind-tools=9.16.48-r0 \
      dnsmasq=2.86-r4
