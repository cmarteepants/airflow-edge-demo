# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PyCascades 2026 demo (presenting March 21): a busy/on-air sign on an RGB LED matrix panel, orchestrated by Apache Airflow 3 (open source). Showcases two Airflow 3 features: **Edge Executor** (running tasks on IoT hardware) and **multi-executor task routing** (sensor on laptop, LED task on Pi, in one DAG).

Flow: Zoom meeting detected via macOS process inspection → Airflow sensor detects change → Edge Worker on Raspberry Pi updates LED panel.

## Pinned Versions

| Package | Version |
| --- | --- |
| `apache-airflow` | 3.1.8 |
| `apache-airflow-providers-edge3` | 3.2.0 (overrides constraint; needed for worker concurrency control) |
| `apache/airflow` Docker image | `3.1.8` |

Edge3 3.2.0 is not in the Airflow 3.1.8 constraints file (which pins 3.1.0), but its PyPI metadata declares `>=3.0.0` compatibility. Install with constraints first, then upgrade edge3 separately.

## Architecture

- **Laptop**: Airflow 3 via Docker Compose + a native macOS Zoom monitor script. No Astro/vendor dependency.
- **Pi Zero 2 W**: Edge Worker only (full `apache-airflow` pip install required, but no server components). Connects to laptop via Tailscale.
- **Zoom detection**: `scripts/zoom_monitor.py` runs natively on macOS, polls for `CptHost` process (Zoom's meeting process). Creates `zoom-state/active` (repo-relative flag file) when a meeting starts, deletes it when it ends. Docker bind-mounts `./zoom-state:/tmp/zoom-state:ro` into all Airflow containers. Use `scripts/zoom-sim.sh start|end|status` to simulate without Zoom.
- **LED display**: A persistent service (`scripts/led_display.py`) on the Pi reads `/tmp/led-state.json` and drives the panel. Three states: **idle** (dim "PYCASCADES" — default when no state file), **ON AIR** (red), **FREE** (green). Airflow tasks write to the state file and exit — they do NOT hold GPIO or run persistently. Use `zoom-sim.sh reset` to delete the state file and return to idle.
- See `docs/architecture.md` for full system diagram and data flow.

### Rejected Approaches

- **Astro CLI / Astronomer**: Rejected — demo must be fully open source, no vendor dependency.
- **Kafka/Redpanda + Asset events**: Rejected — added infrastructure complexity (extra container, Kafka connection, AssetWatcher) without matching the talk's message. The talk is about Edge Executor and physical-world orchestration, not event-driven scheduling.
- **Zoom API polling**: Rejected — rate limits, OAuth scopes, internet dependency. macOS process detection (`CptHost`) is simpler, works offline, and detects the same thing.
- **Zoom webhooks**: Rejected — requires Zoom app registration, ngrok tunnel, internet. Too many moving parts for a live demo on conference WiFi.
- **Airflow task as LED process**: Rejected — `rpi-rgb-led-matrix` holds GPIO while running. If the Airflow task IS the LED process, it never exits and gets killed on timeout. Use a state-file pattern instead.
- **SSH-based task execution from Airflow**: Fallback only if Edge Worker can't run on the Pi. Less impressive for the demo.
- **Lightweight/standalone edge worker**: Does not exist. The edge worker imports deeply from airflow-core (config, JWT auth, task SDK supervisor). AIP-69 acknowledges "thin deployment" as a future goal, not current reality. Full `apache-airflow` pip install is required.
- **JSON content-based zoom status file**: Rejected — `zoom_monitor.py` initially wrote `{"status": "on_air"}` / `{"status": "free"}`. Switched to file existence (create/delete flag) so we can use `FileSensor` for the start condition and a one-line custom sensor for the end condition.
- **`mode="reschedule"` sensors**: Broken in Airflow 3.1.8 — sensor correctly marks itself `up_for_reschedule` but the scheduler fails to honor it, leaving the task in `failed` state. Use `mode="poke"` instead. Not a resource concern for this demo.
- **`@task.sensor` decorator**: Under consideration for deprecation in Airflow 3. Kept for now as it's the most Pythonic option, but watch for removal.
- **Running Airflow natively on laptop for process detection**: Rejected — would require a local edge worker + native Airflow install to access macOS processes from a DAG task. The bind-mounted flag file is simpler and makes the architecture story clearer for the audience.

## Running the Stack

### Laptop (Docker Compose)

```bash
cp .env.example .env  # then edit JWT secret
docker compose build
docker compose up -d
# UI at http://localhost:8081 — login: admin / admin
```

Port 8081 because OrbStack uses 8080 on this machine. The internal container port is still 8080.

### Pi Edge Worker

Airflow is installed in `~/airflow-edge-venv` on the Pi. Both the edge worker and LED display run as systemd services — see `scripts/systemd/` for unit files and install instructions. Manual start is no longer needed.

The edge worker needs the same multi-executor alias config as the server (`LocalExecutor,edge3:airflow.providers.edge3.executors.EdgeExecutor`) because it validates executor names locally when loading DAGs for task execution.

## Airflow 3 Auth

Airflow 3 uses `SimpleAuthManager` — no `airflow users create` command. Users and roles are defined via `AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS` (format: `username:role`). Passwords are stored in a JSON file pointed to by `AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE`. The file format is `{"username": "password"}`. Our passwords file is at `config/simple_auth_passwords.json`.

The `secret_key` config moved from `[webserver]` to `[api]` in Airflow 3. Use `AIRFLOW__API__SECRET_KEY`, not `AIRFLOW__WEBSERVER__SECRET_KEY`.

## Hardware

- **Pi**: Raspberry Pi Zero 2 W (ARM Cortex-A53, 416MB usable RAM + 2.5GB swap configured)
- **Pi SSH**: `ssh airflow-demo` (user: `constance`, key: `~/.ssh/pycascades_pi`, Tailscale IP: `100.92.1.2`)
- **Laptop Tailscale IP**: `100.113.75.99` (this is what `EDGE_HOST_IP` in `.env` must be set to)
- **LED panel**: 64x32 RGB, connected via Adafruit RGB Matrix Bonnet (#3211) + ribbon cable
- **LED library**: `rpi-rgb-led-matrix` built from source at `~/rpi-rgb-led-matrix` on the Pi
- **LED panel flags (mandatory for ALL commands)**: `--led-rows=32 --led-cols=64 --led-slowdown-gpio=4 --led-no-hardware-pulse --led-gpio-mapping=adafruit-hat`
- **Panel commands require `sudo`** — passwordless sudo must be configured for the LED script
- See `docs/hardware.md` for full reference.

## Key Airflow 3 Patterns

- **Continuous scheduling**: `schedule="@continuous"` + `max_active_runs=1` + `start_date=datetime(2026, 3, 1)`. One DAG run = one meeting lifecycle. After each run completes, the scheduler immediately creates the next. **`start_date` must be a `datetime` object** — a string causes a parse error. **Never manually trigger** while the DAG is running — it creates a queued run that blocks `@continuous` from chaining.
- **DAG structure**: `wait_for_meeting_start (sensor, poke) → set_on_air (edge) → wait_for_meeting_end (sensor, poke) → set_free (edge)`
- **Multi-executor in one DAG**: Sensor tasks on `LocalExecutor` (laptop/Docker), LED tasks on `EdgeExecutor` (Pi)
- **Edge task routing**: `@task(executor="edge3", queue="raspberry_pi")`
- **Multi-executor config**: `LocalExecutor,edge3:airflow.providers.edge3.executors.EdgeExecutor` (alias required — see `docs/gotchas.md`)
- **EdgeDBManager required**: Set `AIRFLOW__DATABASE__EXTERNAL_DB_MANAGERS=airflow.providers.edge3.models.db.EdgeDBManager` or edge DB tables won't be created
- **Pi DAGs folder**: `~/airflow-edge-demo/dags/` (set in `~/pi-edge-env.sh`). Sync with `rsync -av dags/ airflow-demo:~/airflow-edge-demo/dags/`
- See `docs/edge-executor.md` for details.

## Important Constraints

- All polling intervals at 1s (zoom monitor, sensor poke, scheduler heartbeat, edge job poll, UI auto-refresh). Average end-to-end latency ~3.5s.
- Edge worker and LED display on Pi run as systemd services (`edge-worker`, `led-display`) — auto-restart on crash, auto-start on boot. Unit files in `scripts/systemd/`.
- Docker images must be pre-cached before the conference (no WiFi dependency).
- Scheduler health check must be explicitly enabled: `AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK=true` (disabled by default in Airflow 3).

## Docs

- `docs/architecture.md` — Full system architecture and data flow
- `docs/edge-executor.md` — Edge Executor/Worker setup, configuration, Pi considerations
- `docs/hardware.md` — Pi, LED panel, SSH, required flags
- `docs/gotchas.md` — Non-obvious issues that cost debugging time (read every session)
- `docs/startup.md` — Demo startup sequence and troubleshooting for the venue
- `docs/milestones.md` — Build checklist
- `NOTES.md` — Running session log: current state, open questions, next steps

## Start of Session Protocol

At the start of each session, before doing anything else, read `docs/gotchas.md`, `docs/milestones.md`, and the most recent entry in `NOTES.md` and summarize:

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

3. Update `docs/milestones.md`: check off completed milestones, add new ones if needed, remove irrelevant ones.

Keep `CLAUDE.md` authoritative and stable. Keep `NOTES.md` as a running log. Append, don't overwite.
