#!/usr/bin/env bash
set -euo pipefail

PROJECT="docker-net-lab"

# hardcoded but as long as i don't fuck with those it should be fine it isn't that deep
containers=(
  app-bridge
  db-bridge
  metrics-host
  lan-web-macvlan
  offline-worker
)

# Also fine its not that deep
networks=(
  bridge-net
  macvlan-net
)

# yeah- stops containers with some fucky chatgpt bash logic shit
echo "[*] Stopping and removing containers..."
for c in "${containers[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
    echo "    - removing ${c}"
    docker rm -f "${c}"
  else
    echo "    - ${c} not found (skipping)"
  fi
done

# see my comment left above i didn't want to write this myself
echo "[*] Removing custom networks..."
for n in "${networks[@]}"; do
  if docker network ls --format '{{.Name}}' | grep -q "^${n}$"; then
    echo "    - removing ${n}"
    docker network rm "${n}"
  else
    echo "    - ${n} not found (skipping)"
  fi
done

# i dunno dawg im eepy
echo "[*] Optionally removing lab images..."
if docker images --format '{{.Repository}}' | grep -q "^${PROJECT}-"; then
  echo "    - removing images tagged ${PROJECT}-*"
  docker images --format '{{.Repository}}:{{.Tag}}' \
    | grep "^${PROJECT}-" \
    | xargs -r docker rmi
else
  echo "    - no ${PROJECT}-* images found (skipping)"
fi

echo "[*] Cleanup complete."
# echo "cocker='docker-compose'"
