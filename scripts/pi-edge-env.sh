#!/usr/bin/env bash
# Environment variables for the Airflow Edge Worker on the Pi.
# Source this file before starting the worker:
#   source ~/pi-edge-env.sh
#   airflow edge worker -q raspberry_pi -c 1
#
# The JWT secret MUST match the central Airflow server's AIRFLOW__API_AUTH__JWT_SECRET.
# Copy the value from .env (AIRFLOW_JWT_SECRET) on the laptop.

# --- Edit these values ---
LAPTOP_IP="${LAPTOP_IP:-100.113.75.99}"    # Tailscale IP of the laptop running Docker Compose
LAPTOP_PORT="${LAPTOP_PORT:-8081}"          # Host port mapped to apiserver (8081 in docker-compose)
JWT_SECRET="${JWT_SECRET:-CHANGE_ME}"       # Must match AIRFLOW_JWT_SECRET in .env

# --- Derived / fixed values (no need to edit) ---
export AIRFLOW__CORE__EXECUTOR="LocalExecutor,edge3:airflow.providers.edge3.executors.EdgeExecutor"
export AIRFLOW__EDGE__API_URL="http://${LAPTOP_IP}:${LAPTOP_PORT}/edge_worker/v1/rpcapi"
export AIRFLOW__CORE__EXECUTION_API_SERVER_URL="http://${LAPTOP_IP}:${LAPTOP_PORT}/execution/"
export AIRFLOW__API_AUTH__JWT_SECRET="$JWT_SECRET"
export AIRFLOW__EDGE__WORKER_CONCURRENCY=1
export AIRFLOW__EDGE__JOB_POLL_INTERVAL=2
export AIRFLOW__EDGE__HEARTBEAT_INTERVAL=10
export AIRFLOW__CORE__DAGS_FOLDER="$HOME/airflow-edge-demo/dags"
export AIRFLOW__CORE__LOAD_EXAMPLES=false

# Activate the venv
source "$HOME/airflow-edge-venv/bin/activate"
