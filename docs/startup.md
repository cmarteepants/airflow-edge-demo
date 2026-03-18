# Demo Startup Sequence

What to launch and in what order at the venue. Total time: ~2 minutes.

## Prerequisites (done once, before the conference)

- Docker images pre-cached (`docker compose pull`)
- Pi has systemd services enabled (`edge-worker`, `led-display`)
- Laptop and Pi on same Tailscale network
- `.env` file populated (JWT secret, EDGE_HOST_IP=100.113.75.99)

## At the Venue

### 1. Power on the Pi

Plug in the Pi and LED panel. The systemd services start automatically:
- `led-display` — panel shows "FREE" within ~5s
- `edge-worker` — connects to Airflow API within ~30s (slow ARM startup)

No SSH needed unless something goes wrong.

### 2. Start the laptop stack

```bash
./scripts/start-demo.sh
```

This does everything: Docker Compose up, waits for health, starts zoom monitor, unpauses the DAG.

### 3. Run preflight

```bash
./scripts/preflight.sh
```

All 12 checks should pass. If the edge worker check fails, give it another 30s — the Pi is slow to register.

### 4. Demo is live

- Join a Zoom call → panel shows "ON AIR" (expect ~5-10s latency)
- Leave the call → panel shows "FREE"
- The DAG auto-chains via `@continuous` — no manual triggers needed

## Simulate Without Zoom

```bash
./scripts/zoom-sim.sh start    # fake meeting start
./scripts/zoom-sim.sh end      # fake meeting end
./scripts/zoom-sim.sh status   # check current state
```

## Shutdown

```bash
docker compose down
pkill -f zoom_monitor.py
```

Pi services keep running (harmless). To stop them:
```bash
ssh airflow-demo 'sudo systemctl stop edge-worker led-display'
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Preflight: edge worker not connected | Wait 30s, Pi is slow. Check: `ssh airflow-demo 'systemctl status edge-worker'` |
| Preflight: zoom monitor not running | `start-demo.sh` starts it. Manual: `python3 scripts/zoom_monitor.py &` |
| LED stuck on one state | Check Pi service: `ssh airflow-demo 'journalctl -u led-display -f'` |
| DAG stuck / no new runs | Check for queued manual run blocking `@continuous`. Delete it in the UI or with `af runs delete led_sign <run_id>` |
| Sensor never fires | Check `zoom-state/active` exists (or doesn't). Check bind mount: `docker compose exec airflow-scheduler ls /tmp/zoom-state/` |
| Edge task fails | Version mismatch? Both must be Airflow 3.1.8 + edge3 3.2.0. Check: `ssh airflow-demo 'source ~/pi-edge-env.sh && airflow version'` |
