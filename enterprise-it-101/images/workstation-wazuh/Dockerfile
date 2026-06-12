# Lab 14 (SIEM) workstation: the standard workstation plus the Wazuh agent
# PACKAGE (installed, not configured — ossec.conf still says MANAGER_IP;
# enrolling it is the lab), iptables (the firewall-drop active response
# needs it), and sshpass (the intruder box scripts SSH password attempts).
#
# Build AFTER workstation:local (eit.sh build does this in order).
FROM workstation:local

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    iptables \
    sshpass \
    rsyslog \
    && curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH \
       | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
       > /etc/apt/sources.list.d/wazuh.list \
    && apt-get update \
    && apt-get install -y wazuh-agent=4.14.5-1 \
    && rm -rf /var/lib/apt/lists/*
