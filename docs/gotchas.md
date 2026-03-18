# Gotchas

A running list of non-obvious issues that cost debugging time. Read this at the start of every session.

---

## Edge Worker / Networking

### EDGE_HOST_IP must be the laptop's Tailscale IP, not the Pi's
The `.env` file has `EDGE_HOST_IP` — this is the IP the **Pi uses to reach the laptop**. It must be the laptop's Tailscale IP (e.g. `100.113.75.99`), not the Pi's own IP. Easy to get backwards if you're looking up "the Tailscale IP" without being specific about which device.

### Multi-executor alias required on both server AND Pi
The DAG uses `@task(executor="edge3", ...)`. For Airflow to resolve the `edge3` alias, the executor config must use the `alias:class` syntax everywhere:
```
LocalExecutor,edge3:airflow.providers.edge3.executors.EdgeExecutor
```
This must be set identically on the Docker Compose server **and** on the Pi's edge worker env. The Pi validates executor names locally when it picks up a task (DagBag load), so a mismatch on either side throws `UnknownExecutorException: edge3`.

### `docker compose restart` does not pick up env var changes
If you change `.env`, you must run `docker compose up -d` to recreate the containers. `docker compose restart` just restarts the existing containers with the old environment baked in.

### Edge Worker auto-shuts down on version mismatch
The Edge Worker compares its Airflow and edge3 provider versions against the API server on startup. If they don't match exactly, the worker silently shuts itself down. Always pin identical versions on the server and Pi (currently Airflow 3.1.8, edge3 3.2.0).

### Don't expose Postgres port to the host
Port 5432 is often already taken by a local Postgres install. The Airflow containers reach Postgres over the Docker network, so there's no need for a host port mapping. We removed it after hitting a conflict.

---

## Airflow 3 Auth

### `AIRFLOW__WEBSERVER__SECRET_KEY` is deprecated — use `AIRFLOW__API__SECRET_KEY`
The secret key config moved from `[webserver]` to `[api]` in Airflow 3. Using the old env var silently does nothing.

### `airflow edge` CLI only appears if executor env var is set
The `edge` subcommand won't show in `airflow --help` unless `AIRFLOW__CORE__EXECUTOR` includes the EdgeExecutor. Set it before running any `airflow edge` commands on the Pi.

### `airflow users create` does not exist in Airflow 3
Airflow 3 replaced Flask-AppBuilder auth with `SimpleAuthManager`. Users/roles are defined via `AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS` (format: `username:role`). Passwords go in a JSON file pointed to by `AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE`. If you Google "create Airflow user", every result shows the old Airflow 2 command.

### JWT secret env var name differs between `.env` and Airflow config
The `.env` file uses `AIRFLOW_JWT_SECRET` (single underscores, no section prefix). Docker Compose maps this to `AIRFLOW__API_AUTH__JWT_SECRET` (double underscores, Airflow env var convention). On the Pi, you must set `AIRFLOW__API_AUTH__JWT_SECRET` directly — don't copy the `.env` var name verbatim.

---

## Configuration

### EdgeDBManager must be explicitly configured or edge tables silently won't exist
Set `AIRFLOW__DATABASE__EXTERNAL_DB_MANAGERS=airflow.providers.edge3.models.db.EdgeDBManager` on all server components. Without this, `airflow db migrate` won't create edge-specific tables, and edge worker registration/job queueing will fail with confusing database errors. No warning is logged if it's missing.

---

## Installation

### Edge3 3.2.0 is not in Airflow 3.1.8 constraints — install in two steps
The constraints file for 3.1.8 pins edge3 to 3.1.0. To get 3.2.0:
1. Install with constraints (gets all base deps at compatible versions)
2. Then `pip install apache-airflow-providers-edge3==3.2.0` to upgrade edge3 specifically
