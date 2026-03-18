# Architecture

## Overview

A busy/on-air sign on an RGB LED matrix panel, orchestrated by Apache Airflow 3 (open source). Showcases two Airflow 3 features: **Edge Executor** (running a worker on an IoT device) and **continuous scheduling with multi-executor task routing**.

**Story**: Zoom meeting starts → local monitor detects it → Airflow sensor picks up the change → Edge Worker on Raspberry Pi updates LED panel to "ON AIR". Meeting ends → panel goes back to "FREE".

## System Diagram

```
┌─────────────────────── Laptop (Docker Compose) ───────────────────────┐
│                                                                        │
│  ┌──────────────┐    ┌──────────────────────────────────────────┐     │
│  │ zoom_monitor  │    │ Airflow 3                                │     │
│  │ (native macOS │    │                                          │     │
│  │  Python loop) │    │  DAG: led_sign (continuous schedule)     │     │
│  │       │       │    │    ├─ check_zoom (LocalExecutor)         │     │
│  │       ▼       │    │    │    reads /tmp/zoom-status.json      │     │
│  │  /tmp/zoom-   │────│──▶ │    detects status change            │     │
│  │  status.json  │    │    └─ update_led (EdgeExecutor) ─────────│──┐  │
│  └──────────────┘    │         writes /tmp/led-state.json on Pi  │  │  │
│                       │                                          │  │  │
│                       │  Scheduler  · API Server · DAG Processor │  │  │
│                       │  PostgreSQL                              │  │  │
│                       └──────────────────────────────────────────┘  │  │
└────────────────────────────────────────────────────────────────────┘  │
                                                                        │
                         Tailscale tunnel (100.x.x.x)                   │
                                                                        │
┌───────────────────── Raspberry Pi Zero 2 W ─────────────────────┐    │
│                                                                   │    │
│  airflow edge worker -q raspberry_pi -c 1  ◀─────────────────────│────┘
│       │                                                           │
│       ▼                                                           │
│  Task: update_led() → writes /tmp/led-state.json                 │
│                                                                   │
│  LED display service (persistent) → reads /tmp/led-state.json    │
│       │                                                           │
│       ▼                                                           │
│  rpi-rgb-led-matrix  ──▶  64×32 RGB LED Panel                    │
│  (via Adafruit Bonnet)    "ON AIR" / "FREE"                      │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Zoom → Monitor**: A lightweight Python script (`scripts/zoom_monitor.py`) runs natively on macOS. It polls for the `CptHost` process (Zoom's meeting process — present when in a call, absent otherwise) and writes `{"status": "on_air"}` or `{"status": "free"}` to `/tmp/zoom-status.json`.

2. **Monitor → Airflow**: Docker Compose bind-mounts `/tmp/zoom-status.json` into the Airflow containers. The DAG's sensor task (running on `LocalExecutor`) reads this file and detects status changes.

3. **Airflow → Pi**: When the sensor detects a change, the downstream task runs with `executor="edge3"` and `queue="raspberry_pi"`. The Edge Worker on the Pi picks it up over Tailscale and executes it.

4. **Pi → LED Matrix**: The task writes the new status to `/tmp/led-state.json` on the Pi. A persistent LED display service (`scripts/led_display.py`) polls this file and drives the 64×32 RGB panel — "ON AIR" in red or "FREE" in green, with a fade transition between states.

## Airflow 3 Features Showcased

- **Edge Executor + Edge Worker**: Real remote task execution on resource-constrained IoT hardware
- **Multi-executor in one DAG**: Sensor runs on `LocalExecutor` (laptop), LED task runs on `EdgeExecutor` (Pi)
- **Continuous scheduling**: DAG runs in a loop — no cron, always monitoring

## Docker Compose Services (Laptop)

| Service | Purpose |
|---|---|
| `postgres` | Airflow metadata DB |
| `airflow-apiserver` | Web UI + Edge API endpoint |
| `airflow-scheduler` | Schedules DAGs, queues edge tasks |
| `airflow-dag-processor` | Parses DAG files |
| `airflow-triggerer` | Runs deferred operators/triggers |
| `airflow-init` | DB migration (runs once, then exits) |

## Demo Trigger

Primary: `scripts/zoom_monitor.py` running on macOS detects real Zoom meeting status via process inspection. No API keys, no internet dependency, works offline.

Fallback: Manually write to `/tmp/zoom-status.json` to simulate status changes.

## Networking

- **Tailscale** (or any network where the Pi can reach the laptop) handles laptop ↔ Pi connectivity
- Docker Compose exposes Airflow API on port 8081 on the laptop host
- Pi's Edge Worker connects to `http://<host-ip>:8081/edge_worker/v1/rpcapi`
