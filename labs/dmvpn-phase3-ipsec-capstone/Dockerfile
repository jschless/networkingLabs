FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc

RUN apk add --no-cache \
    openssl=3.3.7-r0

RUN install -d -m 0700 /lab /lab/pki

CMD ["sh", "-c", "sleep infinity"]
