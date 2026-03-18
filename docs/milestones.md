# Milestone Plan

PyCascades presentation: March 21, 2026.

## Infrastructure & Edge Worker

- [x] **M1.1** Create project structure: `docker-compose.yaml`, `Dockerfile`, `dags/`, `config/`, `scripts/`
- [x] **M1.2** Write `Dockerfile` extending `apache/airflow:3.1.8` with `apache-airflow-providers-edge3==3.2.0` and `apache-airflow-providers-apache-kafka==1.13.0`
- [x] **M1.3** Write `docker-compose.yaml` with 7 services (postgres, apiserver, scheduler, dag-processor, triggerer, init, redpanda)
- [x] **M1.4** Verify Airflow boots, UI accessible at localhost:8081 (login: admin/admin)
- [x] **M1.5** Pin exact versions — Airflow 3.1.8, edge3 3.2.0, kafka 1.13.0 — matching in both Dockerfile and Pi
- [x] **M1.6** SSH to Pi, install Airflow 3.1.8 + edge3 3.2.0 provider in venv at `~/airflow-edge-venv`
- [x] **M1.7** Create `.env.example` with all configurable values (JWT secret, host IP, UID) and add `.env` to `.gitignore`
- [ ] **M1.8** Configure edge worker env vars on Pi (executor, API URL, JWT secret, DAGs folder)
- [ ] **M1.9** Configure passwordless `sudo` on Pi for the LED script/binary (`visudo` NOPASSWD rule for `constance`)
- [ ] **M1.10** Create systemd service for the edge worker on Pi — auto-restart on crash or reboot
- [ ] **M1.11** Start edge worker on Pi, confirm it appears in Airflow UI under Admin → Edge Workers
- [ ] **M1.12** Write a hello-world DAG with `@task(executor="edge3", queue="raspberry_pi")` that prints hostname — trigger it manually and confirm it runs on the Pi, not locally
- [ ] **M1.13** Script or document DAG sync mechanism to Pi (rsync, git clone, or symlink)

## DAGs, LED Scripts & Kafka Integration

- [ ] **M2.1** Design LED display states: "ON AIR" (red background/white text) and "FREE" (green background/white text) — decide layout, font, colors
- [ ] **M2.2** Write a persistent LED display service on the Pi that reads desired state from a file and drives the panel — runs independently of Airflow tasks
- [ ] **M2.3** Airflow task is fire-and-forget: writes status to the state file, then exits. The display service picks up the change.
- [ ] **M2.4** Add a startup/idle state (e.g., "READY" or conference branding) so the panel shows something meaningful before the first event
- [ ] **M2.5** Write the Kafka-triggered DAG: `Asset` + `AssetWatcher` + `KafkaMessageQueueTrigger` watching `zoom-status` topic
- [ ] **M2.6** Write the LED task in the DAG: writes status to state file on Pi, then exits
- [ ] **M2.7** Configure Airflow Kafka connection (`kafka_default`) via environment variable or init script — no manual UI clicks
- [ ] **M2.8** Tune polling intervals for demo responsiveness: `job_poll_interval=2`, `poll_interval=2`, scheduler interval — target under 10s end-to-end
- [ ] **M2.9** Write `scripts/produce_event.py` — primary demo trigger that produces status messages to Redpanda (via REST proxy or kafka protocol)
- [ ] **M2.10** Test manually: produce a message to Redpanda topic → confirm DAG triggers → confirm task runs on Pi → confirm LED updates

## End-to-End Testing & Polish

- [ ] **M3.1** Full pipeline test: produce "in_meeting" → DAG triggers → Pi LED shows "ON AIR"
- [ ] **M3.2** Full pipeline test: produce "available" → DAG triggers → Pi LED shows "FREE"
- [ ] **M3.3** Polish LED display: adjust brightness, font size, contrast for stage visibility

## Hardening & Demo Prep

- [ ] **M4.1** Test full pipeline 3+ times end-to-end
- [ ] **M4.2** Test failure recovery: restart edge worker, restart Airflow, kill Tailscale and reconnect
- [ ] **M4.3** Pre-cache all Docker images (no conference WiFi dependency)
- [ ] **M4.4** Document startup sequence (what to launch in what order at the venue)
- [ ] **M4.5** Write `scripts/start-demo.sh` — single command to launch Docker Compose, wait for health checks, print status
- [ ] **M4.6** Write `scripts/preflight.sh` — verify all services up, edge worker connected, Redpanda topic exists, panel reachable
- [ ] **M4.7** Write a proper `README.md` for the public repo: what this is, architecture diagram, setup instructions, hardware BOM, how to run it
- [ ] **M4.8** Pack hardware: Pi, panel, power supply, cables, laptop charger

## Stretch: Live Zoom Integration

- [ ] **S1** Register Zoom Webhook-only app, subscribe to `user.presence_status_updated` event
- [ ] **S2** Write a small Python webhook receiver script (runs on laptop, not in Docker) that receives Zoom webhook and produces to Redpanda REST proxy
- [ ] **S3** Set up ngrok tunnel, configure Zoom webhook URL
- [ ] **S4** End-to-end test: join Zoom meeting → webhook → Kafka → Airflow → Pi → LED
