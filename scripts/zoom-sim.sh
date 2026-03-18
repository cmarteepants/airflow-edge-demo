#!/bin/bash
# Simulate Zoom meeting start/end for DAG testing.
# Usage: ./scripts/zoom-sim.sh start | end | status | reset

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/demo-config.sh"
FLAG="$SCRIPT_DIR/../zoom-state/active"

case "$1" in
  start)
    touch "$FLAG"
    echo "Meeting started (flag created)"
    ;;
  end)
    rm -f "$FLAG"
    echo "Meeting ended (flag deleted)"
    ;;
  status)
    if [ -f "$FLAG" ]; then
      echo "IN MEETING (flag exists)"
    else
      echo "FREE (no flag)"
    fi
    ;;
  reset)
    ssh "$PI_HOST" 'rm -f /tmp/led-state.json'
    echo "LED panel reset to idle (state file deleted on Pi)"
    ;;
  *)
    echo "Usage: $0 {start|end|status|reset}"
    exit 1
    ;;
esac
