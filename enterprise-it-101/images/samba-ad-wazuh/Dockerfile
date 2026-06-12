# Lab 14 (SIEM) domain controller: samba-ad plus the Wazuh agent PACKAGE.
#
# The agent is installed but deliberately NOT configured or started — its
# ossec.conf still says <address>MANAGER_IP</address>. Pointing it at the
# manager, enrolling it, and wiring up the Samba audit log are the lab.
#
# Build AFTER samba-ad:local (eit.sh build does this in order).
FROM samba-ad:local

ENV DEBIAN_FRONTEND=noninteractive

# Wazuh apt repo (multi-arch: amd64 + arm64). Pin the agent to the same
# 4.14.x line as the wazuh/wazuh-manager image in the lab compose file —
# agents must never be newer than their manager.
RUN apt-get update && apt-get install -y --no-install-recommends gnupg \
    && curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH \
       | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
       > /etc/apt/sources.list.d/wazuh.list \
    && apt-get update \
    && apt-get install -y wazuh-agent=4.14.5-1 \
    && rm -rf /var/lib/apt/lists/*

# Pre-built per DESIGN.md: Samba audit logging is enabled on dc1 so the
# student has a real AD security log to ship (they wire it into the agent
# themselves). Applied by the base entrypoint's post-provision hook.
COPY post-provision-hook.sh /usr/local/bin/post-provision-hook.sh
RUN chmod +x /usr/local/bin/post-provision-hook.sh
