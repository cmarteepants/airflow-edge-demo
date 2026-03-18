# Milestone Plan

PyCascades presentation: March 21, 2026.

## Infrastructure & Edge Worker

- [x] **M1.1** Create project structure: `docker-compose.yaml`, `Dockerfile`, `dags/`, `config/`, `scripts/`
- [x] **M1.2** Write `Dockerfile` extending `apache/airflow:3.1.8` with `apache-airflow-providers-edge3==3.2.0`
- [x] **M1.3** Write `docker-compose.yaml` with services (postgres, apiserver, scheduler, dag-processor, triggerer, init)
- [x] **M1.4** Verify Airflow boots, UI accessible at localhost:8081 (login: admin/admin)
- [x] **M1.5** Pin exact versions — Airflow 3.1.8, edge3 3.2.0 — matching in both Dockerfile and Pi
- [x] **M1.6** SSH to Pi, install Airflow 3.1.8 + edge3 3.2.0 provider in venv at `~/airflow-edge-venv`
- [x] **M1.7** Create `.env.example` with all configurable values (JWT secret, host IP, UID) and add `.env` to `.gitignore`
- [x] **M1.8** Configure edge worker env vars on Pi (executor, API URL, JWT secret, DAGs folder) — `scripts/pi-edge-env.sh` deployed to `~/pi-edge-env.sh`
- [x] **M1.9** Configure passwordless `sudo` on Pi for the LED script/binary (`visudo` NOPASSWD rule for `constance`)
- [x] **M1.10** Create systemd services for edge worker + LED display on Pi — auto-restart on crash, auto-start on boot (`scripts/systemd/`)
- [x] **M1.11** Start edge worker on Pi, confirm it appears in Airflow UI under Admin → Edge Workers
- [x] **M1.12** Write a hello-world DAG with `@task(executor="edge3", queue="raspberry_pi")` — ran successfully on Pi
- [x] **M1.13** DAG sync script: `scripts/sync-dags.sh` (rsync wrapper)

## LED Display

- [x] **M2.1** Design LED display states: "ON AIR" (red text, red border, blinking dot on black) and "FREE" (green text, green border on black)
- [x] **M2.2** Write persistent LED display service (`scripts/led_display.py`) on Pi — reads `/tmp/led-state.json`, drives panel, fade transitions between states
- [x] **M2.3** Install `rgbmatrix` Python bindings on Pi (system Python, Makefile build with Pillow shim stub)
- [x] **M2.4** Three display states: "idle" (dim "PYCASCADES" on boot), "ON AIR" (red), "FREE" (green). `zoom-sim.sh reset` returns to idle.

## Zoom Monitor & DAG

- [x] **M2.5** Write `scripts/zoom_monitor.py` — creates/deletes `zoom-state/active` flag file on meeting start/end
- [x] **M2.6** Add bind mount `./zoom-state:/tmp/zoom-state:ro` in Docker Compose
- [x] **M2.7** Write the DAG: `wait_for_meeting_start → set_on_air → wait_for_meeting_end → set_free`, `@continuous` scheduling, `mode="poke"` sensors
- [x] **M2.8** `scripts/zoom-sim.sh` — simulate Zoom start/end/status for testing without real Zoom
- [x] **M2.9** Polling intervals tuned to 1s across the board (monitor, sensor, scheduler, edge poll). UI refresh 1s. Avg latency ~3.5s.
- [x] **M2.10** Test with real Zoom: join call → confirm LED shows ON AIR → leave → confirm FREE

## End-to-End Testing & Polish

- [x] **M3.1** Full pipeline test: join Zoom → "ON AIR" on panel
- [x] **M3.2** Full pipeline test: leave Zoom → "FREE" on panel
- [ ] **M3.3** Polish LED display: adjust brightness, font size, contrast for stage visibility

## Hardening & Demo Prep

- [ ] **M4.1** Test full pipeline 3+ times end-to-end
- [x] **M4.2** Test failure recovery: kill edge worker (systemd restarts), restart Docker Compose (pipeline resumes), kill zoom monitor (start-demo.sh recovers)
- [x] **M4.3** Pre-cache all Docker images (no conference WiFi dependency)
- [x] **M4.4** Document startup sequence (`docs/startup.md`)
- [x] **M4.5** Write `scripts/start-demo.sh` — single command to launch Docker Compose, wait for health checks, print status
- [x] **M4.6** Write `scripts/preflight.sh` — verify all services up, edge worker connected, panel reachable (12 checks)
- [x] **M4.7** Write a proper `README.md` for the public repo
- [ ] **M4.8** Pack hardware: Pi, panel, power supply, cables, laptop charger
- [x] **M4.9** M1.9 — passwordless sudo on Pi
- [x] **M4.10** M1.10 — systemd services for edge worker + LED display on Pi
