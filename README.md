# Airflow Edge Demo: ON AIR Sign

A live demo for [PyCascades 2026](https://2026.pycascades.com/) (March 21) showing Apache Airflow 3's **Edge Executor** orchestrating physical hardware. A Python script on a MacBook detects when you join a Zoom call, an Airflow sensor picks up the change, and an edge task fires across the network to a Raspberry Pi Zero 2 W — which lights up a 64x32 RGB LED panel with "ON AIR" in red. Leave the call, and it flips back to "FREE" in green. The entire meeting lifecycle is one continuously-scheduled DAG with sensors and LED tasks routed to different executors in the same graph.

## Architecture

```text
┌──────────── MacBook (native) ────────────┐
│                                           │
│  zoom_monitor.py                          │
│    polls for Zoom process (CptHost)       │
│    creates/deletes zoom-state/active      │
│               │                           │
└───────────────│───────────────────────────┘
                │  bind-mount
┌───────────────▼─── Docker Compose ────────┐
│                                            │
│  Airflow 3 (scheduler, API server, etc.)   │
│                                            │
│  DAG: led_sign (@continuous)               │
│    wait_for_meeting_start ─► set_on_air    │
│    wait_for_meeting_end   ─► set_free      │
│    ────────────────────      ──────────    │
│    LocalExecutor (sensor)    EdgeExecutor  │
│                              (Pi task)     │
└──────────────────────────────│─────────────┘
                               │  Tailscale
┌──────────────────────────────▼─────────────┐
│  Raspberry Pi Zero 2 W                      │
│                                             │
│  Edge Worker picks up task                  │
│    writes /tmp/led-state.json               │
│                                             │
│  LED display service (persistent)           │
│    reads state file → drives 64×32 panel    │
│    "ON AIR" (red) / "FREE" (green)          │
└─────────────────────────────────────────────┘
```

## Airflow 3 Features Demonstrated

**Edge Executor** — Tasks execute on a remote Raspberry Pi running an Edge Worker. The Pi connects to the Airflow API server over Tailscale and pulls jobs from its queue. No SSH, no agents, no custom scripts — just Airflow's built-in remote execution.

**Multi-executor task routing** — One DAG, two executors. Sensor tasks run locally on `LocalExecutor` inside Docker. LED tasks run on `EdgeExecutor` targeting the `raspberry_pi` queue. Routing is a single decorator argument: `@task(executor="edge3", queue="raspberry_pi")`.

**Continuous scheduling** — `schedule="@continuous"` with `max_active_runs=1` creates an infinite loop: each DAG run represents one meeting lifecycle, and the next run starts immediately after the previous one completes. No cron, no manual triggers.

## Tech Stack

| Component | Detail |
| --- | --- |
| Apache Airflow | 3.1.8 |
| Edge3 provider | `apache-airflow-providers-edge3` 3.2.0 |
| Laptop infra | Docker Compose (PostgreSQL, scheduler, API server, DAG processor, triggerer) |
| Pi hardware | Raspberry Pi Zero 2 W, 64x32 RGB LED panel, Adafruit RGB Matrix Bonnet |
| LED library | `rpi-rgb-led-matrix` (C library with Python bindings, built from source) |
| Networking | Tailscale (Pi ↔ laptop) |
| Zoom detection | macOS process inspection (`CptHost`) — no API keys, works offline |

## Quick Start

Full setup details are in [`docs/startup.md`](docs/startup.md). The short version:

```bash
# 1. Configure
cp .env.example .env   # set JWT secret and EDGE_HOST_IP

# 2. Start everything (Docker, zoom monitor, DAG)
./demo start

# 3. Verify all components are healthy
./demo preflight

# 4. Join a Zoom call (or simulate one)
./demo sim start    # fake a meeting start
./demo sim end      # fake a meeting end
./demo sim reset    # return panel to idle
```

The Airflow UI is at [http://localhost:8081](http://localhost:8081) (admin / admin).

## Project Structure

```text
demo                         # CLI entrypoint: ./demo start|preflight|sim|sync
dags/
  led_sign_dag.py            # The DAG: sensors + edge tasks in one graph
scripts/
  zoom_monitor.py          # macOS-native Zoom detection (polls CptHost process)
  zoom-sim.sh              # Simulate Zoom start/end without a real meeting
  led_display.py           # Persistent LED panel service (runs on Pi)
  start-demo.sh            # One-command laptop startup
  preflight.sh             # Health checks for all components
  pi-edge-env.sh           # Environment variables for Pi edge worker
  setup-pi.sh              # Pi initial setup script
  systemd/                 # Unit files for Pi services (edge-worker, led-display)
config/
  simple_auth_passwords.json.example
docs/
  architecture.md          # System diagram and data flow
  startup.md               # Full startup sequence and troubleshooting
  edge-executor.md         # Edge Executor setup and configuration
  hardware.md              # Pi, LED panel, wiring, required flags
  gotchas.md               # Non-obvious issues and their fixes
docker-compose.yaml        # Airflow stack (6 services + PostgreSQL)
Dockerfile                 # Custom Airflow image with edge3 provider
```

## Links

- [PyCascades 2026](https://2026.pycascades.com/)
- [Apache Airflow documentation](https://airflow.apache.org/docs/)
- [AIP-69: Edge Executor](https://cwiki.apache.org/confluence/display/AIRFLOW/AIP-69+Edge+Executor) — the design proposal behind Edge Workers
- [`apache-airflow-providers-edge3` on PyPI](https://pypi.org/project/apache-airflow-providers-edge3/)
