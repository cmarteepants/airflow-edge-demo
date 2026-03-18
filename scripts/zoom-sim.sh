#!/bin/bash
# Simulate Zoom meeting start/end for DAG testing.
# Usage: ./scripts/zoom-sim.sh start | end | status | reset

FLAG="$(dirname "$0")/../zoom-state/active"

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
    ssh airflow-demo 'rm -f /tmp/led-state.json'
    echo "LED panel reset to idle (state file deleted on Pi)"
    ;;
  *)
    echo "Usage: $0 {start|end|status|reset}"
    exit 1
    ;;
esac
