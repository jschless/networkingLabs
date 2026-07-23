#!/usr/bin/env bash
set -eu
if [ "${ROLE:-}" = pep ]; then exec python3 /opt/zt/zt_service.py pep; fi
if [ "${ROLE:-}" = pki ]; then exec python3 /opt/zt/zt_service.py pki; fi
if [ "${ROLE:-}" = log ]; then exec python3 /opt/zt/zt_service.py log; fi
if [[ "${ROLE:-}" == *-app ]]; then exec python3 /opt/zt/zt_service.py app; fi
exec tail -f /dev/null
