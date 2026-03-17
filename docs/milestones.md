# Milestone Plan

PyCascades presentation: March 21, 2026. Today: March 17. 4 days.

## Infrastructure & Edge Worker

- [ ] **M1.1** Create project structure: `docker-compose.yaml`, `Dockerfile`, `dags/`, `plugins/`, `include/`, `zoom-bridge/`
- [ ] **M1.2** Write `Dockerfile` extending `apache/airflow:3.0.0` with `apache-airflow-providers-edge3` and `apache-airflow-providers-apache-kafka`
- [ ] **M1.3** Write `docker-compose.yaml` with all 8 services (postgres, apiserver, scheduler, dag-processor, triggerer, init, redpanda, zoom-bridge)
- [ ] **M1.4** Verify Airflow boots, UI accessible at localhost:8080
- [ ] **M1.5** Pin exact versions of `airflow`, `apache-airflow-providers-edge3`, and `apache-airflow-providers-apache-kafka` in both `Dockerfile` and Pi requirements — versions must match
- [ ] **M1.6** SSH to Pi, install Airflow + edge3 provider, configure edge worker
- [ ] **M1.7** Configure passwordless `sudo` on Pi for the LED script/binary (`visudo` NOPASSWD rule for `constance`)
- [ ] **M1.8** Create systemd service for the edge worker on Pi — auto-restart on crash or reboot
- [ ] **M1.9** Start edge worker on Pi, confirm it appears in Airflow logs/UI as registered
- [ ] **M1.10** Create `.env.example` with all configurable values (Tailscale IP, JWT secret, Airflow image version) and add `.env` to `.gitignore`
- [ ] **M1.11** Script or document DAG sync mechanism to Pi (rsync, git clone, or symlink)

## DAGs, LED Scripts & Kafka Integration

- [ ] **M2.1** Design LED display states: "ON AIR" (red background/white text) and "FREE" (green background/white text) — decide layout, font, colors
- [ ] **M2.2** Write a persistent LED display service on the Pi that reads desired state from a file and drives the panel — runs independently of Airflow tasks
- [ ] **M2.3** Airflow task is fire-and-forget: writes status to the state file, then exits. The display service picks up the change.
- [ ] **M2.4** Add a startup/idle state (e.g., "READY" or conference branding) so the panel shows something meaningful before the first event
- [ ] **M2.5** Write the Kafka-triggered DAG: `Asset` + `AssetWatcher` + `KafkaMessageQueueTrigger` watching `zoom-status` topic
- [ ] **M2.6** Write the LED task in the DAG: writes status to state file on Pi, then exits
- [ ] **M2.7** Configure Airflow Kafka connection (`kafka_default`) via environment variable or init script — no manual UI clicks
- [ ] **M2.8** Tune polling intervals for demo responsiveness: `job_poll_interval=2`, `poll_interval=2`, scheduler interval — target under 10s end-to-end
- [ ] **M2.9** Test manually: produce a message to Redpanda topic → confirm DAG triggers → confirm task runs on Pi → confirm LED updates
- [ ] **M2.10** Write `zoom-bridge` Flask app: receives webhook POST, produces to Redpanda

## Zoom Integration & End-to-End

- [ ] **M3.1** Register Zoom Webhook-only app (or use existing Zoom app), subscribe to `user.presence_status_updated` event
- [ ] **M3.2** Set up ngrok tunnel to zoom-bridge service, configure Zoom webhook URL
- [ ] **M3.3** End-to-end test: join a Zoom meeting → webhook fires → Kafka → Airflow → Pi → LED shows "ON AIR"
- [ ] **M3.4** Leave meeting → LED shows "FREE"
- [ ] **M3.5** Write a manual demo script (`produce_test_event.py`) as backup for live demo failure
- [ ] **M3.6** Polish LED display after end-to-end testing: adjust brightness, font size, contrast for stage visibility

## Hardening & Demo Prep

- [ ] **M4.1** Test full pipeline 3+ times end-to-end
- [ ] **M4.2** Test failure recovery: restart edge worker, restart Airflow, kill Tailscale and reconnect
- [ ] **M4.3** Pre-cache all Docker images (no conference WiFi dependency)
- [ ] **M4.4** Prepare offline fallback: if Zoom webhook or ngrok fails, demo using `produce_test_event.py`
- [ ] **M4.5** Document startup sequence (what to launch in what order at the venue)
- [ ] **M4.6** Write `scripts/start-demo.sh` — single command to launch Docker Compose, wait for health checks, print status
- [ ] **M4.7** Write `scripts/preflight.sh` — verify all services up, edge worker connected, Redpanda topic exists, panel reachable
- [ ] **M4.8** Write a proper `README.md` for the public repo: what this is, architecture diagram, setup instructions, hardware BOM, how to run it
- [ ] **M4.9** Pack hardware: Pi, panel, power supply, cables, laptop charger
