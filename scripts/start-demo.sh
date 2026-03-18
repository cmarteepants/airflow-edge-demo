#!/bin/bash
set -euo pipefail

# PyCascades 2026 demo startup script
# Starts Docker Compose, waits for health, launches zoom monitor, unpauses DAG.

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✔${RESET} $1"; }
fail() { echo -e "  ${RED}✘${RESET} $1"; }
info() { echo -e "  ${YELLOW}…${RESET} $1"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo -e "\n${BOLD}Starting PyCascades demo${RESET}\n"

# --- 1. Docker Compose ---
info "Starting Docker Compose..."
docker compose up -d --quiet-pull
ok "Docker Compose started"

# --- 2. Wait for health checks ---
info "Waiting for services to become healthy (up to 60s)..."
TIMEOUT=60
ELAPSED=0
while true; do
    # Count services that are both in our target list and healthy
    HEALTHY_COUNT=$(docker compose ps --format json 2>/dev/null \
        | python3 -c "
import sys, json
targets = {'postgres', 'airflow-apiserver', 'airflow-scheduler'}
count = sum(1 for line in sys.stdin if line.strip()
            and json.loads(line).get('Service') in targets
            and json.loads(line).get('Health') == 'healthy')
print(count)
" 2>/dev/null || echo "0")

    if [[ "$HEALTHY_COUNT" -ge 3 ]]; then
        break
    fi

    if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
        fail "Timed out waiting for services to become healthy"
        echo "  Run 'docker compose ps' to check status"
        exit 1
    fi

    sleep 2
    ELAPSED=$((ELAPSED + 2))
done
ok "postgres healthy"
ok "airflow-apiserver healthy"
ok "airflow-scheduler healthy"

# --- 3. Zoom monitor ---
if pgrep -f 'zoom_monitor\.py' > /dev/null 2>&1; then
    ok "Zoom monitor already running (pid $(pgrep -f 'zoom_monitor\.py'))"
else
    info "Starting zoom monitor..."
    python3 "$REPO_ROOT/scripts/zoom_monitor.py" >> /tmp/zoom_monitor.log 2>&1 &
    ok "Zoom monitor started (pid $!, log: /tmp/zoom_monitor.log)"
fi

# --- 4. Unpause led_sign DAG ---
info "Unpausing led_sign DAG..."

# Get JWT token
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8081/auth/token \
    -H 'Content-Type: application/json' \
    -d '{"username":"admin","password":"admin"}')

TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || true)

if [[ -z "$TOKEN" ]]; then
    fail "Could not get auth token — is the API server ready?"
    echo "  Response: $TOKEN_RESPONSE"
    exit 1
fi

UNPAUSE_RESPONSE=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH \
    http://localhost:8081/api/v2/dags/led_sign \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"is_paused": false}')

if [[ "$UNPAUSE_RESPONSE" == "200" ]]; then
    ok "led_sign DAG unpaused"
else
    fail "Failed to unpause DAG (HTTP $UNPAUSE_RESPONSE)"
fi

# --- 5. Status summary ---
echo -e "\n${BOLD}Demo ready${RESET}\n"
echo -e "  Airflow UI:     ${GREEN}http://localhost:8081${RESET}  (admin / admin)"
echo -e "  Zoom monitor:   running natively (log: /tmp/zoom_monitor.log)"
echo -e "  Simulate Zoom:  ${BOLD}./scripts/zoom-sim.sh start${RESET}  /  ${BOLD}end${RESET}  /  ${BOLD}status${RESET}"
echo -e "  Pi edge worker:  managed separately via systemd"
echo ""
