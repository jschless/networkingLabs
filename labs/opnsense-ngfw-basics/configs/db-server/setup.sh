#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.30.30.10/24 dev eth1
ip route replace default via 10.30.30.1

cat >/tmp/db-response.sh <<'EOF'
#!/bin/bash
printf 'Welcome to the protected DB tier\n'
EOF
chmod +x /tmp/db-response.sh
nohup socat TCP-LISTEN:3306,reuseaddr,fork EXEC:/tmp/db-response.sh >/tmp/db.log 2>&1 &

echo "[db-server] Ready"
echo "  IP:       10.30.30.10/24"
echo "  Gateway:  10.30.30.1"
echo "  Service:  TCP 3306"
