#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.30.30.10/24 dev eth1
ip route replace default via 10.30.30.1

cat >/tmp/serve-db.sh <<'EOF'
#!/bin/bash
BANNER="Welcome to the protected DB tier\n"
while true; do
    printf "$BANNER" | nc -l -p 3306 -q 1 2>/dev/null || true
done
EOF
chmod +x /tmp/serve-db.sh
nohup bash /tmp/serve-db.sh >/tmp/db.log 2>&1 &

echo "[db-server] Ready"
echo "  IP:       10.30.30.10/24"
echo "  Gateway:  10.30.30.1"
echo "  Service:  TCP 3306"
