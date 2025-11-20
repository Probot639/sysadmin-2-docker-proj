#!/usr/bin/env bash
set -euo pipefail

PROJECT="docker-net-lab"

# keep these in sync with build.sh
MACVLAN_IP="129.21.136.169"
HOST_MACVLAN_IF="macvlan0"

RED="$(tput setaf 1 || true)"
GRN="$(tput setaf 2 || true)"
YEL="$(tput setaf 3 || true)"
RST="$(tput sgr0 || true)"

pass() { echo "${GRN}[PASS]${RST} $*"; }
fail() { echo "${RED}[FAIL]${RST} $*"; }
warn() { echo "${YEL}[WARN]${RST} $*"; }

echo "== Docker Networking Lab Health Check =="

# 1) Docker daemon available
if docker info >/dev/null 2>&1; then
  pass "Docker daemon reachable"
else
  fail "Docker daemon not reachable (is dockerd running?)"
  exit 1
fi

# 2) Networks exist
for net in bridge-net macvlan-net; do
  if docker network inspect "$net" >/dev/null 2>&1; then
    pass "Network '$net' exists"
  else
    fail "Network '$net' is missing"
  fi
done

# 2.5) Host-side macvlan interface
if ip link show "$HOST_MACVLAN_IF" >/dev/null 2>&1; then
  pass "Host macvlan interface '$HOST_MACVLAN_IF' exists"
else
  warn "Host macvlan interface '$HOST_MACVLAN_IF' missing (host -> macvlan container reachability may fail)"
fi

# 3) Containers running
containers=(
  app-bridge
  db-bridge
  metrics-host
  lan-web-macvlan
  offline-worker
)

for c in "${containers[@]}"; do
  state="$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo "missing")"
  if [ "$state" = "running" ]; then
    pass "Container '$c' is running"
  elif [ "$state" = "exited" ]; then
    fail "Container '$c' exists but is exited"
  else
    fail "Container '$c' is missing"
  fi
done

# 4) HTTP check: app-bridge via localhost:8080
if command -v curl >/dev/null 2>&1; then
  if curl -fsS http://localhost:8080 >/dev/null 2>&1; then
    pass "app-bridge reachable at http://localhost:8080"
  else
    fail "app-bridge NOT reachable at http://localhost:8080"
  fi
else
  warn "curl not found; skipping HTTP checks"
fi

# 5) bridge connectivity: app-bridge -> db-bridge (ping)
if docker exec app-bridge ping -c1 -W1 db-bridge >/dev/null 2>&1; then
  pass "app-bridge can reach db-bridge over bridge-net (ping ok)"
else
  fail "app-bridge cannot reach db-bridge over bridge-net"
fi

# 6) metrics-host: host network, node exporter on :9100
if command -v curl >/dev/null 2>&1; then
  if curl -fsS http://127.0.0.1:9100/metrics >/dev/null 2>&1; then
    pass "metrics-host exposing /metrics on host port 9100"
  else
    fail "metrics-host NOT reachable on http://127.0.0.1:9100/metrics"
  fi
fi

# 7) macvlan-web: from host, should be reachable now that we have HOST_MACVLAN_IF
if command -v curl >/dev/null 2>&1; then
  if curl --max-time 3 -fsS "http://${MACVLAN_IP}" >/dev/null 2>&1; then
    pass "lan-web-macvlan reachable at http://${MACVLAN_IP} from host"
  else
    fail "lan-web-macvlan NOT reachable at http://${MACVLAN_IP} from host"
  fi
else
  warn "curl not found; skipping macvlan HTTP check"
fi

# 8) offline-worker: verify /logs volume
if docker exec offline-worker ls /logs >/dev/null 2>&1; then
  pass "offline-worker has /logs volume mounted"
else
  fail "offline-worker missing /logs volume"
fi

# 9) offline-worker: verify container is up and has no Internet
offline_id="$(docker ps -q -f name=^offline-worker)"

if [ "${#offline_id}" -le 4 ]; then
  fail "offline-worker container is not running"
elif docker exec offline-worker ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
  fail "offline-worker can ping Internet (expected NO network)"
else
  pass "offline-worker is running and cannot ping Internet (network isolation working)"
fi

echo
echo "== Health check complete =="

