FROM python:3.12.7-alpine3.20@sha256:5049c050bdc68575a10bcb1885baa0689b6c15152d8a56a7e399fb49f783bf98

RUN apk add --no-cache \
      bash \
      curl \
      git \
      iproute2 \
      iputils \
      jq \
      tcpdump \
    && pip install --no-cache-dir \
      Jinja2==3.1.5 \
      jsonschema==4.23.0 \
      pytest==8.3.4 \
      PyYAML==6.0.2

CMD ["sleep", "infinity"]
