#!/bin/bash
set -e

OPENNMS_URL="http://172.31.30.42:8980/opennms"
AUTH="admin:admin"

echo "[opennms-bootstrap] Waiting for OpenNMS HTTP endpoint..."
until curl -sf "${OPENNMS_URL}/login.jsp" >/dev/null 2>&1; do
    sleep 10
done

echo "[opennms-bootstrap] Waiting for REST API..."
until curl -sf -u "${AUTH}" "${OPENNMS_URL}/rest/info" >/dev/null 2>&1; do
    sleep 10
done

echo "[opennms-bootstrap] Uploading requisition..."
curl -sf -u "${AUTH}" \
    -H "Content-Type: application/xml" \
    --data-binary @/config/requisition.xml \
    "${OPENNMS_URL}/rest/requisitions"

echo "[opennms-bootstrap] Importing requisition..."
curl -sf -u "${AUTH}" -X PUT \
    "${OPENNMS_URL}/rest/requisitions/telemetry-hybrid/import?rescanExisting=true"

echo "[opennms-bootstrap] Requisition imported"
