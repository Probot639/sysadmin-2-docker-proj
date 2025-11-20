#!/usr/bin/env bash
set -euo pipefail

PROJECT="docker-net-lab"

# === CHANGE THESE FOR YOUR LAN ===
PARENT_IF="wlan0"              # physical interface

SUBNET="129.21.136.0/22"       # LAN subnet (matches 129.21.136.168/22)
GATEWAY="129.21.139.1"         # router IP (verify with: ip route | grep default)

MACVLAN_IP="129.21.136.169"    # free IP on your LAN for the container
HOST_MACVLAN_IF="macvlan0"     # host-side macvlan interface name
HOST_MACVLAN_IP="129.21.136.170"  # another free IP on the same /22 for the host
# ================================

# derive prefix from SUBNET (e.g. "129.21.136.0/22" -> "22")
SUBNET_PREFIX="${SUBNET##*/}"

echo "[*] Building images..."

docker build -t ${PROJECT}-app-bridge ./bridge-app
docker build -t ${PROJECT}-db-bridge ./bridge-db
docker build -t ${PROJECT}-metrics-host ./metrics-host
docker build -t ${PROJECT}-macvlan-web ./macvlan-web
docker build -t ${PROJECT}-offline-worker ./offline-worker

echo "[*] Creating networks..."

# create bridge network for app + DB
if ! docker network inspect bridge-net >/dev/null 2>&1; then
  docker network create bridge-net
fi

# create macvlan network for LAN-facing web container
if ! docker network inspect macvlan-net >/dev/null 2>&1; then
  docker network create -d macvlan \
    --subnet="${SUBNET}" \
    --gateway="${GATEWAY}" \
    -o parent="${PARENT_IF}" \
    macvlan-net
fi

# create a host-side macvlan interface so the HOST can talk to macvlan containers
if ! ip link show "${HOST_MACVLAN_IF}" >/dev/null 2>&1; then
  echo "[*] Creating host macvlan interface ${HOST_MACVLAN_IF} on ${PARENT_IF}..."
  sudo ip link add "${HOST_MACVLAN_IF}" link "${PARENT_IF}" type macvlan mode bridge
  sudo ip addr add "${HOST_MACVLAN_IP}/${SUBNET_PREFIX}" dev "${HOST_MACVLAN_IF}"
  sudo ip link set "${HOST_MACVLAN_IF}" up
fi

echo "[*] Removing any old containers..."

docker rm -f app-bridge db-bridge metrics-host lan-web-macvlan offline-worker 2>/dev/null || true

echo "[*] Starting containers..."

# Run the database container on the bridge network and set up the env vars cause mariadb reasons
docker run -d --name db-bridge \
  --network bridge-net \
  -e MARIADB_ROOT_PASSWORD=example-root \
  -e MARIADB_DATABASE=demo \
  -e MARIADB_USER=demo \
  -e MARIADB_PASSWORD=demo-pass \
  ${PROJECT}-db-bridge

# website
docker run -d --name app-bridge \
  --network bridge-net \
  -p 8080:80 \
  ${PROJECT}-app-bridge

# logs but useful
docker run -d --name metrics-host \
  --network host \
  ${PROJECT}-metrics-host

# website but weirder cause its on my own IP an shit
docker run -d --name lan-web-macvlan \
  --network macvlan-net \
  --ip "${MACVLAN_IP}" \
  ${PROJECT}-macvlan-web

# make the logs do something idk
docker run -d --name offline-worker \
  --network none \
  -v "$(pwd)/logs:/logs:ro" \
  ${PROJECT}-offline-worker

# its very late and i wish i was more tired but i'm not so oh well
echo
echo "[*] All containers started."
echo
echo "Showing stuff off:"
echo "- curl http://localhost:8080"
echo "- docker network inspect bridge-net"
echo "- curl http://localhost:9100/metrics"
echo "- curl http://${MACVLAN_IP}     # from THIS HOST (via ${HOST_MACVLAN_IF})"
echo "- docker logs offline-worker"
echo "- docker exec -it app-bridge sh"
echo "- and ^^ ping db-bridge"

