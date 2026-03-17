# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PyCascades 2026 demo (presenting March 21): a busy/on-air sign on an RGB LED matrix panel, orchestrated by Apache Airflow 3 (open source). Showcases two Airflow 3 features: **Edge Executor** and **event-driven scheduling via Assets**.

Flow: Zoom status change → Kafka topic (Redpanda) → Airflow Asset event → Edge Worker on Raspberry Pi → LED panel update.

## Architecture

- **Laptop**: Airflow 3 + Redpanda + Zoom webhook bridge, all via Docker Compose. No Astro/vendor dependency.
- **Pi Zero 2 W**: Edge Worker only (full `apache-airflow` pip install required, but no server components). Connects to laptop via Tailscale.
- **Messaging**: Redpanda (single-container Kafka-compatible broker). Chosen over Apache Kafka for simplicity — one container, no ZooKeeper, ~150MB RAM, starts in seconds. Airflow's Kafka provider works unchanged.
- **LED display**: A persistent service on the Pi reads state from a file and drives the panel. Airflow tasks write to the state file and exit — they do NOT hold GPIO or run persistently. This avoids Airflow task timeouts and GPIO conflicts.
- See `docs/architecture.md` for full system diagram and data flow.

### Rejected Approaches

- **Astro CLI / Astronomer**: Rejected — demo must be fully open source, no vendor dependency.
- **Apache Kafka (full)**: Rejected — requires 2-3 containers (broker + ZooKeeper/KRaft), ~1GB+ RAM, 30s startup. Overkill for a laptop demo.
- **Webhook workaround instead of Kafka**: Rejected — the whole point is demoing real Airflow 3 Asset event-driven scheduling, not faking it.
- **Airflow task as LED process**: Rejected — `rpi-rgb-led-matrix` holds GPIO while running. If the Airflow task IS the LED process, it never exits and gets killed on timeout. Use a state-file pattern instead.
- **SSH-based task execution from Airflow**: Fallback only if Edge Worker can't run on the Pi. Less impressive for the demo.

## Hardware

- **Pi**: Raspberry Pi Zero 2 W (ARM Cortex-A53, 416MB usable RAM + 2.5GB swap configured)
- **Pi SSH**: `ssh airflow-demo` (user: `constance`, key: `~/.ssh/pycascades_pi`, Tailscale IP: `100.92.1.2`)
- **LED panel**: 64x32 RGB, connected via Adafruit RGB Matrix Bonnet (#3211) + ribbon cable
- **LED library**: `rpi-rgb-led-matrix` built from source at `~/rpi-rgb-led-matrix` on the Pi
- **LED panel flags (mandatory for ALL commands)**: `--led-rows=32 --led-cols=64 --led-slowdown-gpio=4 --led-no-hardware-pulse --led-gpio-mapping=adafruit-hat`
- **Panel commands require `sudo`** — passwordless sudo must be configured for the LED script
- See `docs/hardware.md` for full reference.

## Key Airflow 3 Patterns

- **Event-driven DAG**: `Asset` + `AssetWatcher` + `KafkaMessageQueueTrigger` (not cron, not sensor polling)
- **Edge task routing**: `@task(executor="edge3", queue="raspberry_pi")`
- **Multi-executor**: `LocalExecutor,airflow.providers.edge3.executors.EdgeExecutor`
- **Version pinning is critical**: Edge Worker auto-shuts-down on version mismatch with server. Pin exact versions of `airflow`, `edge3`, and `kafka` provider in both Dockerfile and Pi.
- See `docs/edge-executor.md` and `docs/messaging-layer.md` for details.

## Important Constraints

- All polling intervals (Kafka trigger, edge worker job poll, scheduler) should be tuned low for demo responsiveness — target <10s end-to-end latency.
- Edge worker on Pi needs a systemd service for auto-restart on crash/reboot.
- The `kafka_default` connection must be set up via environment variable or init script, not manual UI clicks.
- Docker images must be pre-cached before the conference (no WiFi dependency).

## Docs

- `docs/architecture.md` — Full system architecture and data flow
- `docs/messaging-layer.md` — Redpanda (Kafka) setup and Airflow integration pattern
- `docs/edge-executor.md` — Edge Executor/Worker setup, configuration, Pi considerations
- `docs/hardware.md` — Pi, LED panel, SSH, required flags
- `docs/milestones.md` — Build checklist
- `NOTES.md` — Running session log: current state, open questions, next steps

## Start of Session Protocol
At the start of each session, before doing anything else, read the most recent entry in `NOTES.md` and summarize:
- Current state
- Open questions
- What we're doing this session

## End of Session Protocol
At the end of each session, do the following without being asked:
1. Update `CLAUDE.md` with any new architecture decisions, rejected approaches and why, hardware details, or project conventions discovered this session. Remove anything that's now outdated.
2. Update `NOTES.md` with:
  - Current state (what's working, what's broken)
  - Open questions needing a decision
  - The single most important thing to do at the start of next session

  Keep `CLAUDE.md` authoritative and stable. Keep `NOTES.md` as a running log. Append, don't overwite. 
