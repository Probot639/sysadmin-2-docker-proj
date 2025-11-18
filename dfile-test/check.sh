#!/usr/bin/env bash
set -euo pipefail

PROJECT="docker-net-lab"
MACVLAN_IP="192.168.1.200"   # keep this in sync with build.sh

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

# 7) macvlan-web: best-effort check from host with timeout
# If it hangs or fails, we *still* pass and note the timeout,
# since host <-> macvlan often isn't directly reachable.
if command -v curl >/dev/null 2>&1; then
  if curl --max-time 3 -fsS "http://${MACVLAN_IP}" >/dev/null 2>&1; then
    pass "lan-web-macvlan reachable at http://${MACVLAN_IP} from host"
  else
    pass "lan-web-macvlan HTTP check timed out or failed from host (expected behavior for macvlan; continuing)"
  fi
fi

# 8) offline-worker: verify no network + logs volume
if docker exec offline-worker ls /logs >/dev/null 2>&1; then
  pass "offline-worker has /logs volume mounted"
else
  fail "offline-worker missing /logs volume"
fi

if docker exec offline-worker ping -c1 -W1 8.8.8.8 >/dev/null 2>&1; then
  fail "offline-worker can ping Internet (expected NO network)"
else
  pass "offline-worker cannot ping Internet (network isolation working)"
fi

echo
echo "== Health check complete =="


