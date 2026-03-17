# NOTES.md

Running session log. Append only — newest entries at the bottom.

---

## Session 1 — March 17, 2026

### What's working

- Pi Zero 2 W is online and reachable via `ssh airflow-demo` (Tailscale)
- LED panel confirmed working with `rpi-rgb-led-matrix` demo binary
- Swap expanded to 2.5GB (512MB zram + 2GB `/var/swap`), persists via `/etc/fstab`
- Architecture designed and documented in `docs/`
- Milestone plan written in `docs/milestones.md`

### What's not done yet

- No code written — project structure is still just docs + skeleton
- No Docker Compose, no Dockerfile, no DAGs, no zoom-bridge
- No Airflow installed on Pi yet
- No LED display script (persistent service + state file pattern)
- No Kafka connection, no Redpanda config

### Decisions made

1. **Redpanda** over Apache Kafka — lighter, single container, Kafka-compatible
2. **State-file pattern for LED** — persistent display service on Pi reads state from file; Airflow task writes file and exits. Avoids GPIO hold / task timeout issues.
3. **Multi-executor** — `LocalExecutor` + `EdgeExecutor` in the same Airflow instance
4. **Passwordless sudo** needed on Pi for LED commands
5. **Systemd service** for edge worker on Pi — auto-restart on crash/reboot
6. **Version pinning** — exact match required between server and edge worker

### Open questions

- [ ] Which exact Airflow 3.x version to use? 3.0.0 is stable but 3.1+ has edge worker UI pages. Need to verify edge3 provider compatibility with chosen version.
- [ ] Zoom webhook app — does Constance already have a Zoom app registered, or do we need to create one from scratch?
- [ ] LED display design — what font/colors/layout? Block letters? Scrolling? Static centered text?
- [ ] State file location on Pi — where should the Airflow task write? `/tmp/led-state.json`? Somewhere more durable?
- [ ] Does the LED display service need its own systemd unit, or can it be a simple `while True` Python loop started in a tmux/screen session?

### Next session: start here

**M1.1–M1.4**: Create the project structure and get Airflow booting in Docker Compose. This unblocks everything else. Specifically:
1. Create `Dockerfile` with pinned versions
2. Create `docker-compose.yaml` with all 8 services
3. Verify Airflow UI at localhost:8080
