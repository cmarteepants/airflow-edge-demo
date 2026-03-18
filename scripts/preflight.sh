#!/bin/bash
set -euo pipefail

# Pre-demo preflight check for PyCascades 2026 LED sign demo.
# Verifies all components are running and reports pass/fail for each.

AIRFLOW_URL="http://localhost:8081"
PASS=0
FAIL=0

pass() {
  echo "  ✓ $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  ✗ $1"
  FAIL=$((FAIL + 1))
}

check() {
  local description="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    pass "$description"
  else
    fail "$description"
  fi
}

echo "=== Preflight Check ==="
echo ""

# --- 1. Docker Compose services ---
echo "Docker Compose services:"
for svc in airflow-apiserver airflow-scheduler airflow-dag-processor airflow-triggerer postgres; do
  status=$(docker compose ps --format '{{.Status}}' "$svc" 2>/dev/null || true)
  if echo "$status" | grep -qiE '(healthy|running|Up)'; then
    pass "$svc ($status)"
  else
    fail "$svc (${status:-not found})"
  fi
done
echo ""

# --- 2. Zoom monitor running locally ---
echo "Local processes:"
check "Zoom monitor (zoom_monitor.py)" pgrep -f zoom_monitor.py
echo ""

# --- 3. Pi reachable ---
echo "Raspberry Pi:"
check "Pi reachable (ssh airflow-demo)" ssh -o ConnectTimeout=5 airflow-demo true
check "Edge worker on Pi" ssh -o ConnectTimeout=5 airflow-demo systemctl is-active edge-worker
check "LED display on Pi" ssh -o ConnectTimeout=5 airflow-demo systemctl is-active led-display
echo ""

# --- 4. Airflow API checks ---
echo "Airflow API:"

# Get JWT token
TOKEN=$(curl -s -X POST "${AIRFLOW_URL}/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || true)

# Edge worker connected (check for active polling or startup message in recent logs)
if ssh -o ConnectTimeout=5 airflow-demo 'journalctl -u edge-worker --no-pager -n 50 2>/dev/null | grep -qE "(No new job to process|Starting worker with API endpoint)"' 2>/dev/null; then
  pass "Edge worker connected to API"
else
  fail "Edge worker connected to API (no activity in recent logs)"
fi

if [ -z "$TOKEN" ]; then
  fail "Auth token (could not authenticate)"
else
  # DAG exists and unpaused
  dag_response=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "${AIRFLOW_URL}/api/v2/dags/led_sign" 2>/dev/null || true)
  is_paused=$(echo "$dag_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_paused','unknown'))" 2>/dev/null || echo "unknown")
  if [ "$is_paused" = "False" ] || [ "$is_paused" = "false" ]; then
    pass "DAG led_sign exists and unpaused"
  else
    fail "DAG led_sign (is_paused=$is_paused)"
  fi
fi
echo ""

# --- 5. Zoom-state directory mounted in scheduler ---
echo "Container mounts:"
check "zoom-state mounted in scheduler" docker compose exec -T airflow-scheduler test -d /tmp/zoom-state
echo ""

# --- Summary ---
TOTAL=$((PASS + FAIL))
echo "=== $PASS/$TOTAL checks passed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
