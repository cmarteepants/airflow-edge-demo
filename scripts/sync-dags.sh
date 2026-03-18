#!/bin/bash
set -euo pipefail

# Sync DAGs to the Raspberry Pi edge worker.
# Usage: ./scripts/sync-dags.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PI_HOST="airflow-demo"
PI_DAGS="~/airflow-edge-demo/dags/"

echo "Syncing dags/ → ${PI_HOST}:${PI_DAGS}"
rsync -av --delete \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    "$REPO_ROOT/dags/" \
    "${PI_HOST}:${PI_DAGS}"
echo "Done."
