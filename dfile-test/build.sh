#!/usr/bin/env bash
set -euo pipefail

PROJECT="docker-net-lab"

# === CHANGE THESE FOR YOUR LAN ===
PARENT_IF="wlan0"           # physical interface
SUBNET="192.168.1.0/24"     # LAN subnet
GATEWAY="192.168.1.1"       # router IP
MACVLAN_IP="192.168.1.200"  # a free IP in your LAN
# ================================

echo "[*] Building images..."

docker build -t ${PROJECT}-app-bridge ./bridge-app
docker build -t ${PROJECT}-db-bridge ./bridge-db
docker build -t ${PROJECT}-metrics-host ./metrics-host
docker build -t ${PROJECT}-macvlan-web ./macvlan-web
docker build -t ${PROJECT}-offline-worker ./offline-worker

echo "[*] Creating networks..."

# Bridge network for app + DB
if ! docker network inspect bridge-net; then
  docker network create bridge-net
fi

# Macvlan network for LAN-facing web container
if ! docker network inspect macvlan-net; then
  docker network create -d macvlan \
    --subnet="${SUBNET}" \
    --gateway="${GATEWAY}" \
    -o parent="${PARENT_IF}" \
    macvlan-net
fi

echo "[*] Removing any old containers..."

docker rm -f app-bridge db-bridge metrics-host lan-web-macvlan offline-worker

echo "[*] Starting containers..."

# 1) DB on bridge-net (internal-only)
docker run -d --name db-bridge \
  --network bridge-net \
  -e MARIADB_ROOT_PASSWORD=example-root \
  -e MARIADB_DATABASE=demo \
  -e MARIADB_USER=demo \
  -e MARIADB_PASSWORD=demo-pass \
  ${PROJECT}-db-bridge

# 2) App on bridge-net, published to host
docker run -d --name app-bridge \
  --network bridge-net \
  -p 8080:80 \
  ${PROJECT}-app-bridge

# 3) Host-networked metrics container
docker run -d --name metrics-host \
  --network host \
  ${PROJECT}-metrics-host

# 4) Macvlan web container with its own LAN IP
docker run -d --name lan-web-macvlan \
  --network macvlan-net \
  --ip "${MACVLAN_IP}" \
  ${PROJECT}-macvlan-web

# 5) Offline worker with NO network, just a volume
docker run -d --name offline-worker \
  --network none \
  -v "$(pwd)/logs:/logs:ro" \
  ${PROJECT}-offline-worker

echo
echo "[*] All containers started."
echo
echo "Showing stuff off:"
echo "- curl http://localhost:8080"
echo "- docker network inspect bridge-net"
echo "- curl http://localhost:9100/metrics"
echo "- curl http://${MACVLAN_IP}"
echo "- docker logs offline-worker"
echo "- docker exec -it app-bridge sh"
echo "- and ^^ ping db-bridge"

