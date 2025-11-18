#!/usr/bin/env bash
set -euo pipefail

PROJECT="docker-net-lab"

# === CHANGE THESE FOR YOUR LAN ===
PARENT_IF="wlan0"           # physical interface
                            # TODO change this interface depending on the computer this is running on
SUBNET="192.168.1.0/24"     # LAN subnet
GATEWAY="192.168.1.1"       # router IP
MACVLAN_IP="192.168.1.200"  # a free IP in your LAN
                            # These might also need to be changed but so far I haven't had to
# ================================

echo "[*] Building images..."

docker build -t ${PROJECT}-app-bridge ./bridge-app
docker build -t ${PROJECT}-db-bridge ./bridge-db
docker build -t ${PROJECT}-metrics-host ./metrics-host
docker build -t ${PROJECT}-macvlan-web ./macvlan-web
docker build -t ${PROJECT}-offline-worker ./offline-worker

echo "[*] Creating networks..."

# create bridge network for app + DB
if ! docker network inspect bridge-net; then
  docker network create bridge-net
fi

# create macvlan network for LAN-facing web container
# as a reminder this is what allows the docker container to use the host's network instead of the regular docker one
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
echo "- curl http://${MACVLAN_IP}"
echo "- docker logs offline-worker"
echo "- docker exec -it app-bridge sh"
echo "- and ^^ ping db-bridge"

