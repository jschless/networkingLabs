#!/bin/bash
set -e

ip link set eth1 up
ip link set eth1 promisc on

if ip link show eth2 >/dev/null 2>&1; then
  ip link set eth2 up
  ip addr add 192.0.2.2/30 dev eth2 2>/dev/null || true
fi

mkdir -p /var/log/zeek /var/log/suricata /var/log/yara /var/log/soc /pcap /extract_files

cat > /usr/local/bin/generate-soc-artifacts << 'EOF'
#!/bin/bash
set -e

mkdir -p /var/log/zeek /var/log/suricata /var/log/yara /var/log/soc /pcap /extract_files

cat > /var/log/zeek/conn.log << 'LOG'
{"ts":"2026-04-18T12:00:00Z","uid":"C1","id.orig_h":"10.10.10.10","id.resp_h":"172.16.10.10","id.resp_p":80,"proto":"tcp","service":"http","duration":0.031,"orig_bytes":148,"resp_bytes":96,"conn_state":"SF"}
{"ts":"2026-04-18T12:00:04Z","uid":"C2","id.orig_h":"10.10.10.10","id.resp_h":"172.16.20.10","id.resp_p":8080,"proto":"tcp","service":"http","duration":0.020,"orig_bytes":110,"resp_bytes":42,"conn_state":"SF"}
{"ts":"2026-04-18T12:00:08Z","uid":"C3","id.orig_h":"10.10.10.10","id.resp_h":"172.16.10.10","id.resp_p":22,"proto":"tcp","service":"ssh","duration":0.004,"orig_bytes":0,"resp_bytes":0,"conn_state":"S0"}
LOG

cat > /var/log/zeek/http.log << 'LOG'
{"ts":"2026-04-18T12:00:00Z","uid":"C1","id.orig_h":"10.10.10.10","id.resp_h":"172.16.10.10","method":"GET","host":"dmz-web","uri":"/downloads/readme.txt","status_code":200,"user_agent":"soc-lab-curl"}
{"ts":"2026-04-18T12:00:04Z","uid":"C2","id.orig_h":"10.10.10.10","id.resp_h":"172.16.20.10","method":"GET","host":"dmz-api","uri":"/healthz","status_code":200,"user_agent":"soc-lab-curl"}
LOG

cat > /var/log/zeek/notice.log << 'LOG'
{"ts":"2026-04-18T12:00:09Z","note":"Scan::Port_Scan","src":"10.10.10.10","msg":"attacker scanned DMZ high-value targets"}
LOG

cat > /extract_files/readme.txt << 'LOG'
SOC_LAB_TEST_FILE harmless file transfer for Zeek and YARA exercises
LOG

cat > /var/log/suricata/eve.json << 'LOG'
{"timestamp":"2026-04-18T12:00:09.000000+0000","event_type":"alert","src_ip":"10.10.10.10","src_port":42424,"dest_ip":"172.16.10.10","dest_port":22,"proto":"TCP","alert":{"signature_id":900001,"signature":"SOC LAB Possible SSH brute force","category":"Attempted Administrator Privilege Gain","severity":2}}
{"timestamp":"2026-04-18T12:00:10.000000+0000","event_type":"alert","src_ip":"10.10.10.10","src_port":51514,"dest_ip":"172.16.10.10","dest_port":80,"proto":"TCP","alert":{"signature_id":900002,"signature":"SOC LAB Suspicious SQLi probe","category":"Web Application Attack","severity":1}}
LOG

cat > /var/log/yara/hits.json << 'LOG'
{"timestamp":"2026-04-18T12:00:11Z","rule":"SOC_LAB_Test_File","file":"/extract_files/readme.txt","sha256":"local-demo","tags":["file-transfer","benign"]}
LOG

cat > /var/log/soc/detection-matrix.json << 'LOG'
[
  {"ttp":"T1046","name":"Network Service Discovery","source":"Zeek notice + Suricata scan rule","status":"detected"},
  {"ttp":"T1110","name":"Brute Force","source":"Suricata SSH rule","status":"detected"},
  {"ttp":"T1595","name":"Active Scanning","source":"Zeek connection burst","status":"detected"}
]
LOG

cat > /var/log/soc/incident-timeline.md << 'LOG'
# SOC Lab Incident Timeline

- 2026-04-18T12:00:00Z attacker browsed dmz-web
- 2026-04-18T12:00:04Z attacker checked dmz-api health endpoint
- 2026-04-18T12:00:09Z scan behavior detected
- 2026-04-18T12:00:10Z web attack pattern detected
LOG

touch /pcap/soc-lab-demo.pcap
EOF

chmod +x /usr/local/bin/generate-soc-artifacts
/usr/local/bin/generate-soc-artifacts

echo "[sensor] mirror interface eth1 ready; generated Zeek, Suricata, YARA, and SOC artifacts"
