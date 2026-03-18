# Architecture

## Overview

A busy/on-air sign on an RGB LED matrix panel, orchestrated by Apache Airflow 3 (open source). Showcases two Airflow 3 features: **Edge Executor** (running a worker on an IoT device) and **event-driven scheduling via Assets**.

**Story**: Zoom meeting status changes → event published to a Kafka-compatible topic → Airflow DAG triggered via Asset event → Edge Worker on a Raspberry Pi picks up the task → LED panel updates to show busy or free state.

## System Diagram

```
┌─────────────────────── Laptop (Docker Compose) ───────────────────────┐
│                                                                        │
│  ┌──────────┐    ┌───────────┐    ┌──────────────────────────────┐    │
│  │  Zoom     │───▶│ Redpanda  │───▶│ Airflow 3                    │    │
│  │  Bridge   │    │ (Kafka)   │    │                              │    │
│  │  (Flask)  │    │ topic:    │    │  Triggerer                   │    │
│  └──────────┘    │ zoom-     │    │    └─ KafkaMessageQueueTrigger│    │
│       ▲          │  status   │    │         └─ AssetWatcher       │    │
│       │          └───────────┘    │              └─ fires DAG ────│──┐ │
│  Zoom Webhook                     │                              │  │ │
│  (via ngrok)                      │  Scheduler (EdgeExecutor)    │  │ │
│                                   │  API Server (edge API on)    │  │ │
│                                   │  DAG Processor               │  │ │
│                                   │  PostgreSQL                  │  │ │
│                                   └──────────────────────────────┘  │ │
└─────────────────────────────────────────────────────────────────────┘ │
                                                                        │
                          Tailscale tunnel (100.x.x.x)                  │
                                                                        │
┌───────────────────── Raspberry Pi Zero 2 W ─────────────────────┐    │
│                                                                   │    │
│  airflow edge worker -q raspberry_pi -c 1  ◀─────────────────────│────┘
│       │                                                           │
│       ▼                                                           │
│  Task: update_led_panel()                                         │
│       │                                                           │
│       ▼                                                           │
│  rpi-rgb-led-matrix  ──▶  64×32 RGB LED Panel                    │
│  (via Adafruit Bonnet)    "ON AIR" / "FREE"                      │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Zoom → Bridge**: Zoom sends a webhook on meeting status change (`user.presence_status_updated`). A lightweight Flask service receives it and produces a JSON message (`{"status": "in_meeting"}` or `{"status": "available"}`) to Redpanda topic `zoom-status`.

2. **Redpanda → Airflow**: The Airflow **triggerer** runs a `KafkaMessageQueueTrigger` that polls the `zoom-status` topic. This trigger is attached to an `AssetWatcher` on an `Asset("zoom-meeting-status")`. When a message arrives, the asset is marked updated, which triggers the consumer DAG.

3. **Airflow → Pi**: The DAG has a single task with `executor="edge3"` and `queue="raspberry_pi"`. The EdgeExecutor queues it. The Edge Worker on the Pi polls the API server over Tailscale, picks up the task, and executes it.

4. **Pi → LED Matrix**: The task calls `rpi-rgb-led-matrix` Python bindings with the appropriate flags to display "ON AIR" (red) or "FREE" (green) on the 64x32 panel.

## Airflow 3 Features Showcased

- **Asset + AssetWatcher + KafkaMessageQueueTrigger**: Real event-driven scheduling (not cron, not polling from the DAG)
- **EdgeExecutor + Edge Worker**: Real remote task execution on IoT hardware
- **Multi-executor**: LocalExecutor for admin tasks, EdgeExecutor for Pi tasks — in the same Airflow instance

## Docker Compose Services (Laptop)

| Service | Purpose |
|---|---|
| `postgres` | Airflow metadata DB |
| `airflow-apiserver` | Web UI + Edge API endpoint |
| `airflow-scheduler` | Schedules DAGs, queues edge tasks |
| `airflow-dag-processor` | Parses DAG files |
| `airflow-triggerer` | Runs KafkaMessageQueueTrigger |
| `airflow-init` | DB migration (runs once, then exits) |
| `redpanda` | Kafka-compatible message broker |

## Demo Trigger

Events are produced to Redpanda via `scripts/produce_event.py` or Redpanda's REST proxy (port 8082). Live Zoom webhook integration is a stretch goal — see `docs/milestones.md`.

## Networking

- **Tailscale** (or any network where the Pi can reach the laptop) handles laptop ↔ Pi connectivity
- Docker Compose exposes Airflow API on port 8081 on the laptop host
- Pi's Edge Worker connects to `http://<host-ip>:8081/edge_worker/v1/rpcapi`
