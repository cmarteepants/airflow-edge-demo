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

---

## Session 2 — March 17, 2026 (evening)

### What's working

- **Docker Compose stack fully running** on laptop: postgres, apiserver, scheduler, dag-processor, triggerer, redpanda all healthy
- Airflow UI at http://localhost:8081 (port 8081 due to OrbStack on 8080), login: admin/admin
- Redpanda broker healthy, Kafka API on port 9092
- **Airflow installed on Pi**: 3.1.8 + edge3 3.2.0 in `~/airflow-edge-venv`, `airflow version` works, `airflow edge --help` works (with executor env var set)
- EdgeDBManager configured, no warnings in apiserver logs
- Auth working via `SimpleAuthManager` with passwords file at `config/simple_auth_passwords.json`

### What's not working / not done

- Edge worker not yet configured or started on Pi (no env vars, no API URL, no JWT secret, no DAGs folder)
- zoom-bridge container crashes (placeholder `app.py` — expected)
- No DAGs, no LED scripts, no Kafka connection
- No passwordless sudo on Pi
- No systemd services on Pi

### Decisions made this session

1. **Airflow 3.1.8** (not 3.0.x) — for edge worker UI admin pages
2. **Edge3 3.2.0** (overrides constraint file) — needed for worker concurrency control
3. **Port 8081** for Airflow UI — OrbStack uses 8080 on this machine
4. **SimpleAuthManager** for auth — Airflow 3 removed `airflow users create`. Users defined via `SIMPLE_AUTH_MANAGER_USERS` env var, passwords via JSON file.
5. **EdgeDBManager must be explicitly configured** via `AIRFLOW__DATABASE__EXTERNAL_DB_MANAGERS` or edge tables won't be created
6. **`airflow edge` CLI requires executor env var** — without `AIRFLOW__CORE__EXECUTOR=...EdgeExecutor` set, the edge subcommand doesn't appear
7. **Full Airflow pip install required on Pi** — no lightweight edge worker package exists. AIP-69 marks thin deployment as future goal.
8. **Pi install succeeded** with Python 3.13 / ARM64 — piwheels provided pre-built wheels, install took ~5 min with constraints

### Gotchas learned

- Airflow 3.1.8 constraints pin edge3 to 3.1.0. To use 3.2.0: install with constraints first (gets all base deps), then `pip install apache-airflow-providers-edge3==3.2.0` to upgrade.
- `AIRFLOW__WEBSERVER__SECRET_KEY` is deprecated in Airflow 3 — use `AIRFLOW__API__SECRET_KEY`
- Postgres port 5432 was already in use (local Postgres). Removed host port mapping — no need to expose DB outside Docker network.

### Open questions

- [x] ~~Which exact Airflow 3.x version to use?~~ → 3.1.8
- [x] ~~Zoom integration approach?~~ → Stretch goal. Primary trigger is `scripts/produce_event.py`. Zoom webhook is a small standalone script if time allows.
- [ ] LED display design — what font/colors/layout? Block letters? Scrolling? Static centered text?
- [ ] State file location on Pi — where should the Airflow task write? `/tmp/led-state.json`? Somewhere more durable?
- [ ] Does the LED display service need its own systemd unit, or can it be a simple `while True` Python loop started in a tmux/screen session?
- [ ] What JWT secret value should be used on the Pi? Copy from `.env` or generate a shared one?

### Late session updates

- **Removed zoom-bridge** Docker service, `plugins/`, `include/` dirs — not needed
- **Zoom integration moved to stretch goals** (S1–S4 in milestones). Primary demo trigger is `scripts/produce_event.py` using Redpanda REST proxy.
- **Renamed `TAILSCALE_IP` → `EDGE_HOST_IP`** in `.env.example` — not everyone uses Tailscale
- **`af` CLI working** against our stack (`uvx --from astro-airflow-mcp af`). Instance `local-demo` configured at localhost:8081 with admin/admin. Useful for DAG validation.
- **Created `scripts/setup-pi.sh`** — reproducible Pi install script
- **Astronomer plugin skills reviewed** — `authoring-dags` (Airflow 3 imports, Asset patterns), `testing-dags` (`af runs trigger-wait`), and `debugging-dags` are useful. dbt/Astro-specific skills are not.
- **Conventions moved from CLAUDE.md to memory** — CLAUDE.md is public repo, conventions are instructions for Claude

### Next session: start here

**M1.8–M1.12**: Configure and connect the edge worker on the Pi, then validate with a hello-world DAG. Specifically:
1. Set edge worker env vars on Pi (executor, API URL pointing to `$EDGE_HOST_IP:8081`, JWT secret from `.env`)
2. Create a DAGs folder on Pi and sync at least a placeholder DAG
3. Start `airflow edge worker -q raspberry_pi -c 1`
4. Confirm it appears in Airflow UI → Admin → Edge Workers
5. Write and trigger a hello-world DAG that runs on the Pi
