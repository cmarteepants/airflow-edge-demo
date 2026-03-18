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

---

## Session 3 — March 18, 2026

### What's working

- **Edge worker connected and running on Pi** — polling every 2s, heartbeats every 10s, registered as `airflow-demo` in the API server
- **hello_edge DAG** runs successfully end-to-end: triggered via API → scheduler queues → edge worker picks up → executes on Pi (`hostname: airflow-demo`, `arch: aarch64`) → state=success in ~3.5s
- **All Docker Compose services healthy** including scheduler (after enabling health check)
- **Pi env file** (`~/pi-edge-env.sh`) deployed with correct laptop IP, JWT secret, executor config
- **DAG sync via rsync** working (manual, not automated yet)
- **`docs/gotchas.md` created** — consolidated all debugging lessons from sessions 1–3

### What's not working / not done

- Edge worker on Pi runs via `nohup` — no systemd service yet (M1.10)
- No passwordless sudo on Pi (M1.9)
- No DAG sync automation (M1.13)
- No LED scripts, no Kafka DAG, no Kafka connection (M2.x)
- No `scripts/produce_event.py`

### Decisions made this session

1. **`EDGE_HOST_IP` is the laptop's Tailscale IP** (`100.113.75.99`), not the Pi's (`100.92.1.2`) — was set backwards in `.env`
2. **Multi-executor alias syntax required everywhere** — `edge3:airflow.providers.edge3.executors.EdgeExecutor` needed on both server and Pi, not just the server. The Pi validates executor names during DagBag load at task execution time.
3. **Scheduler health check disabled by default in Airflow 3** — must set `AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK=true` explicitly
4. **Airflow 3 API uses JWT tokens** — not basic auth. POST to `/auth/token` with username/password to get a bearer token.
5. **DAG trigger requires `logical_date: null`** — Airflow 3 API rejects empty `{}` body for manual DAG runs

### Gotchas learned

- See `docs/gotchas.md` — consolidated all gotchas from all sessions into one doc this session

### Open questions

- [ ] LED display design — what font/colors/layout? Block letters? Scrolling? Static centered text?
- [ ] State file location on Pi — `/tmp/led-state.json` or somewhere more durable?
- [ ] Does the LED display service need its own systemd unit?

### Next session: start here

**M2 — LED scripts and Kafka DAG**. The infrastructure is proven. Priority is now:
1. M1.9 — passwordless sudo on Pi (quick, unblocks LED work)
2. M2.1–M2.3 — LED display service on Pi (state file pattern + persistent display process)
3. M2.5–M2.7 — Kafka-triggered DAG with Asset + AssetWatcher
4. M2.9 — `scripts/produce_event.py` to test the pipeline
5. M2.10 — First manual end-to-end test

M1.10 (systemd) and M1.13 (DAG sync automation) can wait until hardening phase.

---

## Session 4 — March 18, 2026

### What's working

- **LED display service fully working on Pi** — `scripts/led_display.py` reads `/tmp/led-state.json`, drives 64×32 RGB panel
  - "ON AIR": red text, red border, blinking red dot (~1Hz)
  - "FREE": green text, green border (also the default/idle state)
  - Fade transitions (~500ms) between states via matrix brightness
  - Font: 9x18B, "ON" and "AIR" drawn separately with custom 5px gap
  - Double-buffered rendering via `SwapOnVSync`
- **`rgbmatrix` Python bindings installed** on Pi system Python (Makefile build, Pillow shim stubbed out)
- **Zoom process detection confirmed** — `pgrep CptHost` reliably detects meeting start/end on macOS

### What's not working / not done

- No Zoom monitor script yet (`scripts/zoom_monitor.py`)
- No DAG yet (sensor + edge task with continuous scheduling)
- No Docker Compose bind mount for zoom status file
- Edge worker not currently running on Pi (was stopped during LED testing)
- M1.9 (passwordless sudo) and M1.10 (systemd) deferred to hardening

### Major architecture change this session

**Replaced Kafka/Redpanda/Asset event-driven architecture with a simpler sensor-based approach.** Motivation:
- The talk abstract is about Edge Executor and physical-world orchestration, not event-driven scheduling
- Kafka + Redpanda + AssetWatcher added infrastructure complexity without serving the talk's message
- Sensor + continuous scheduling is standard Airflow patterns, matching the abstract ("familiar Airflow patterns")
- Zoom detection via macOS process inspection (`CptHost`) works offline — no API, no auth, no internet
- Removed: Redpanda container, Kafka provider dependency, Asset/AssetWatcher, zoom-bridge service, `produce_event.py`
- Added: `zoom_monitor.py` (macOS native), continuous DAG scheduling, Docker bind mount

### Gotchas learned

- `RGBMatrix` drops root privileges after init (uid 0 → uid 1/daemon). Load fonts BEFORE creating the matrix. State file must be in a world-readable location (`/tmp`), not under `/home`.
- `rpi-rgb-led-matrix` post-Feb 2026 switched to scikit-build-core — too heavy for Pi Zero. Roll back bindings to commit `076c54b`, stub out `pillow.c`, build with make.
- Pi `/tmp` is a 209MB tmpfs — pip builds overflow it. Use `TMPDIR=~/tmp` for large builds.
- `sudo` on Pi doesn't inherit `PATH` — use full paths like `/usr/bin/python3`.
- `sudo pkill` on Pi can kill the SSH session — use `sudo kill $(pgrep -f ...)` in a separate SSH call.

### Open questions

- [ ] LED display design — final brightness tuning for stage (current default is fine for desk, may need adjustment for stage lighting)

### Next session: start here

**M2.5–M2.9 — Zoom monitor + DAG**. The LED display is done. Priority is now:
1. M2.5 — Write `scripts/zoom_monitor.py` (poll `CptHost`, write `/tmp/zoom-status.json`)
2. M2.6 — Add bind mount in Docker Compose for the zoom status file
3. M2.7 — Write the DAG: continuous scheduling, sensor reads zoom status (LocalExecutor), LED task on Pi (EdgeExecutor)
4. M2.8 — Tune intervals
5. M2.9 — First end-to-end test: join/leave Zoom → LED updates

---

## Session 5 — March 18, 2026

### What's working

- **`scripts/zoom_monitor.py`** — creates/deletes `zoom-state/active` flag file on meeting start/end
- **`scripts/zoom-sim.sh`** — simulate Zoom start/end/status for testing without real Zoom
- **`zoom-state/` directory** — committed to repo with `.gitkeep`, bind-mounted into Docker as `/tmp/zoom-state:ro`
- **`dags/led_sign_dag.py`** — fully written and validated:
  - `@dag` TaskFlow style, `@continuous` + `max_active_runs=1` + `start_date=datetime(2026, 3, 1)`
  - `wait_for_meeting_start (poke sensor) → set_on_air (edge) → wait_for_meeting_end (poke sensor) → set_free (edge)`
  - Scheduler auto-creates next run after each completes ✓
- **End-to-end pipeline tested with zoom-sim.sh**:
  - `zoom-sim.sh start` → sensor fires → `set_on_air` runs on Pi → LED shows ON AIR ✓
  - `zoom-sim.sh end` → sensor fires → `set_free` runs on Pi → LED shows FREE ✓
  - `@continuous` auto-chains next scheduled run after completion ✓
- **LED display service** — starts manually on Pi, reads state file, drives panel correctly

### What's not working / not done

- LED display service must be started manually on Pi each session (`nohup sudo /usr/bin/python3 ~/airflow-edge-demo/scripts/led_display.py > ~/led-display.log 2>&1 &`)
- Edge worker must be started manually on Pi each session (`source ~/pi-edge-env.sh && nohup airflow edge worker -q raspberry_pi -c 1 > ~/edge-worker.log 2>&1 &`)
- No test with real Zoom yet (only zoom-sim.sh)
- M1.9 (passwordless sudo), M1.10 (systemd services), M1.13 (DAG sync automation) deferred to hardening

### Gotchas learned

- `mode="reschedule"` broken in Airflow 3.1.8 — sensor marks `up_for_reschedule` but scheduler fails to honor it → `failed`. Use `mode="poke"`.
- `@continuous` requires `start_date=datetime(...)`, not a string — string causes `AttributeError: 'str' object has no attribute 'utcoffset'`
- Never manually trigger `led_sign` while running — queued run blocks `@continuous` from chaining. Delete it with `af runs delete` if it happens.
- Pi DAGs folder is `~/airflow-edge-demo/dags/` (not `~/dags/`) — wrong rsync target causes `Dag not found during start up` on edge worker
- `FileSensor` only checks file existence, not content — use file existence as the signal (create/delete) rather than JSON content
- `@task.sensor` is under consideration for deprecation in Airflow 3 — kept for now

### Open questions

- [ ] LED brightness tuning for stage lighting (may need adjustment before March 21)

### Next session: start here

**Test with real Zoom + hardening.** Priority:
1. Start LED display service and edge worker on Pi
2. Test with a real Zoom call: join → LED ON AIR, leave → LED FREE
3. M4.4 — Document startup sequence (what to launch and in what order at the venue)
4. M4.9/M4.10 — passwordless sudo + systemd services on Pi (prevents needing SSH at the venue)

---

## Session 6 — March 18, 2026

### What's working

- **Real Zoom test passed**: join Zoom → ON AIR on panel, leave → FREE. Full DAG cycle completed successfully.
- **Systemd services on Pi**: `edge-worker` and `led-display` both enabled and active. Auto-start on boot, auto-restart on failure. No more nohup.
- **`scripts/start-demo.sh`**: Single command starts Docker Compose, waits for health, launches zoom monitor, unpauses DAG.
- **`scripts/preflight.sh`**: 12 checks covering Docker services, zoom monitor, Pi connectivity, systemd services, edge worker registration, DAG state, bind mounts. All passing.
- **`docs/startup.md`**: Full venue startup sequence with troubleshooting table.
- **Passwordless sudo** was already configured on Pi (M4.9 done in a prior session).

### Issues found and fixed

- **Zoom monitor process got stuck**: The long-running `zoom_monitor.py` process (started hours earlier) stopped detecting state changes. CptHost was running but no flag file was created. Killing and restarting the monitor fixed it immediately. Root cause unclear — possibly a `pgrep` subprocess hang. Worth monitoring at the venue.
- **`pgrep -f "airflow edge worker"` doesn't match systemd process**: The systemd-managed process shows as `/home/constance/airflow-edge-venv/bin/python3 ... airflow edge worker`. Switched preflight check to use `systemctl is-active` instead.
- **Edge3 provider has no public REST API for listing workers**: `/api/v2/edge/workers` returns 404. Changed preflight to check edge worker connection via journalctl logs instead.

### Also completed later this session

- **M4.2 — Failure recovery testing**: all three scenarios pass:
  - Kill edge worker on Pi → systemd restarts with new PID (`Restart=always`)
  - `docker compose down` + `start-demo.sh` → healthy in ~12s, DAG still unpaused
  - Kill zoom monitor → `start-demo.sh` detects and restarts it
- **M4.3 — Docker images pre-cached** via `docker compose pull`
- Fixed `start-demo.sh` health check (JSON field order bug) and `preflight.sh` edge worker log check
- Fixed systemd `Restart=on-failure` → `Restart=always` (SIGTERM wasn't triggering restart)
- Cleaned up orphan nohup edge worker process on Pi

### What's not done

- M2.9 — polling interval tuning (current latency is acceptable but not measured precisely)
- M3.3 — LED brightness tuning for stage
- M4.1 — Test full pipeline 3+ times (done twice — once real Zoom, once sim — need one more)
- M4.7 — README.md
- M4.8 — Pack hardware

### Open questions

- [ ] LED brightness tuning for stage lighting
- [ ] Zoom monitor process stability — may need a watchdog or periodic restart

### Next session: start here

**Final polish before March 21.** Priority:
1. M4.1 — One more full end-to-end test for confidence
2. M4.7 — README.md for the public repo
3. M3.3 — LED brightness check (bring panel to a lit room)
4. M4.8 — Pack hardware

---

## Session 7 — March 18, 2026

### What's working

- **Three LED states**: idle (dim "PYCASCADES"), ON AIR (red), FREE (green) — with fade transitions between all
- **`zoom-sim.sh reset`**: deletes state file on Pi, returns panel to idle
- **All polling intervals at 1s**: zoom monitor, sensor poke, scheduler heartbeat, edge job poll, UI auto-refresh. Avg latency ~3.5s.
- **`scripts/sync-dags.sh`**: rsync wrapper for DAG deployment to Pi
- **`README.md`**: full project README with architecture diagram, quick start, project structure
- **Another successful end-to-end test with real Zoom**: idle → ON AIR → FREE, continuous chaining confirmed

### Issues found and fixed

- **SCP'd `pi-edge-env.sh` overwrote JWT secret**: deploying the repo template to Pi replaced the real JWT secret with `CHANGE_ME`, causing 403 Forbidden. Fixed by editing Pi's copy directly. Added gotcha.
- **`start-demo.sh` health check JSON parsing**: grep assumed field order in `docker compose ps --format json` output. Fixed with python parser (from earlier this session, included in this branch).

### Gotchas learned

- Don't SCP `pi-edge-env.sh` over the Pi's configured copy — the repo template has `CHANGE_ME` as the JWT secret default. Edit the Pi's copy directly or set `JWT_SECRET` as an env var.

### What's not done

- M3.3 — LED brightness tuning for stage (current defaults look fine at desk distance)
- M4.1 — Need one more end-to-end rep (done 3 total: 1 sim, 2 real Zoom)
- M4.8 — Pack hardware

### Open questions

- [ ] LED brightness for stage lighting
- [ ] Zoom monitor process stability — no recurrence since restart earlier, but worth watching

### Next session: start here

**Demo is essentially ready.** Remaining before March 21:
1. M3.3 — Test LED brightness in a lit room
2. M4.8 — Pack hardware: Pi, panel, power supply, ribbon cable, USB-C cable, laptop charger
3. One more confidence run if time allows
