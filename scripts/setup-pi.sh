#!/usr/bin/env bash
# Setup script for the Raspberry Pi Edge Worker.
# Run this on the Pi (or via SSH) to install Airflow and the edge3 provider.
#
# Usage:
#   ssh airflow-demo "bash -s" < scripts/setup-pi.sh
#
# Prerequisites:
#   - Python 3.10+ installed
#   - 2GB+ swap configured (Pi Zero 2 W only has 512MB RAM)

set -euo pipefail

AIRFLOW_VERSION="3.1.8"
EDGE3_VERSION="3.2.0"
VENV_DIR="$HOME/airflow-edge-venv"

echo "=== Setting up Airflow Edge Worker ==="
echo "Airflow: $AIRFLOW_VERSION"
echo "Edge3 provider: $EDGE3_VERSION"
echo "Venv: $VENV_DIR"
echo ""

# Check Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Python: $PYTHON_VERSION"

if python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)"; then
    echo "Python version OK"
else
    echo "ERROR: Python 3.10+ required, found $PYTHON_VERSION"
    exit 1
fi

# Check swap
TOTAL_SWAP=$(free -m | awk '/Swap:/ {print $2}')
echo "Swap: ${TOTAL_SWAP}MB"
if [ "$TOTAL_SWAP" -lt 1024 ]; then
    echo "WARNING: Less than 1GB swap. Installation may fail on low-memory devices."
    echo "Consider increasing swap before continuing."
fi

# Create venv
if [ -d "$VENV_DIR" ]; then
    echo "Venv already exists at $VENV_DIR"
else
    echo "Creating venv..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

echo "Upgrading pip..."
pip install --upgrade pip

# Install with constraints, then upgrade edge3
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
echo "Installing Airflow with constraints: $CONSTRAINT_URL"
pip install "apache-airflow-providers-edge3" --constraint "$CONSTRAINT_URL"

echo "Upgrading edge3 provider to $EDGE3_VERSION..."
pip install "apache-airflow-providers-edge3==$EDGE3_VERSION"

# Verify
echo ""
echo "=== Verification ==="
INSTALLED_AIRFLOW=$(pip show apache-airflow 2>/dev/null | grep "^Version:" | awk '{print $2}')
INSTALLED_EDGE3=$(pip show apache-airflow-providers-edge3 2>/dev/null | grep "^Version:" | awk '{print $2}')
echo "apache-airflow: $INSTALLED_AIRFLOW"
echo "apache-airflow-providers-edge3: $INSTALLED_EDGE3"

echo ""
echo "=== Done ==="
echo "Activate with: source $VENV_DIR/bin/activate"
echo "Test with:     AIRFLOW__CORE__EXECUTOR=airflow.providers.edge3.executors.EdgeExecutor airflow edge --help"
