# Systemd Services for the Pi

Two services that auto-start on boot and restart on failure:

- **edge-worker.service** — Airflow Edge Worker (runs as `constance`)
- **led-display.service** — LED display driver (runs as `root` for GPIO access)

## Install

```bash
scp scripts/systemd/*.service airflow-demo:/tmp/
ssh airflow-demo 'sudo cp /tmp/*.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now edge-worker led-display'
```

## Check status

```bash
ssh airflow-demo 'systemctl status edge-worker led-display'
```

## View logs

```bash
ssh airflow-demo 'journalctl -u edge-worker -f'
ssh airflow-demo 'journalctl -u led-display -f'
```
