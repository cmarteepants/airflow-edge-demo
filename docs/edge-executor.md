# Edge Executor & Edge Worker

## How It Works

The Edge Executor uses a **pull-based architecture**. Edge Workers do NOT receive pushed tasks. Instead, they poll the central Airflow API server over HTTPS for available work.

### Central Airflow Server (laptop)

- **Scheduler** with `EdgeExecutor` loaded — writes queued tasks into an `EdgeJobModel` database table
- **API Server** with edge plugin enabled (`api_enabled = True`) — exposes REST endpoints at `/edge_worker/v1/rpcapi`
- **Triggerer** — runs deferred operators and triggers
- **PostgreSQL** — stores edge job queue, worker state, edge logs

### Remote Edge Worker (Raspberry Pi)

- A lightweight `airflow edge worker` process
- A local copy of the DAG files
- Outbound HTTPS connectivity to the API server (no inbound ports needed)

### Communication Flow

1. Scheduler queues a task into `EdgeJobModel` table via the EdgeExecutor
2. Edge Worker polls `POST /jobs/fetch/{hostname}` with its queues and available concurrency slots
3. API Server returns a job if one matches the worker's queues
4. Edge Worker spawns a subprocess to execute the task
5. Edge Worker streams log chunks back via `POST /logs/push/...`
6. Edge Worker reports task completion via `PATCH /jobs/state/...`
7. Edge Worker sends heartbeats via `PATCH /worker/{hostname}` (default 30s interval)

**Key advantage**: Only outbound HTTPS from the edge device is required. No VPN, no message broker, no persistent TCP connections. Works across firewalls and NAT.

## Central Server Configuration

```ini
[core]
executor = LocalExecutor,airflow.providers.edge3.executors.EdgeExecutor

[edge]
api_enabled = true
api_url = http://airflow-apiserver:8080/edge_worker/v1/rpcapi
```

Multi-executor setup: `LocalExecutor` handles normal tasks, `EdgeExecutor` handles tasks routed to edge workers. Tasks specify `executor="edge3"` and `queue="raspberry_pi"` to run on the Pi.

## Edge Worker Configuration (Pi)

The Edge Worker requires a **full `apache-airflow` pip install**. It uses the Airflow CLI, configuration system, and task SDK. It does NOT need a database, Redis, webserver, scheduler, or DAG processor running locally.

### Install

```bash
pip install apache-airflow==3.0.0
pip install apache-airflow-providers-edge3==3.2.0
```

### Configure (environment variables)

Use `scripts/pi-edge-env.sh` — source it before starting the worker. Key variables:

```bash
export AIRFLOW__CORE__EXECUTOR=airflow.providers.edge3.executors.EdgeExecutor
export AIRFLOW__CORE__EXECUTION_API_SERVER_URL=http://<LAPTOP_IP>:8081/execution/
export AIRFLOW__EDGE__API_URL=http://<LAPTOP_IP>:8081/edge_worker/v1/rpcapi
export AIRFLOW__EDGE__WORKER_CONCURRENCY=1
export AIRFLOW__API_AUTH__JWT_SECRET=<SAME_AS_AIRFLOW_JWT_SECRET_IN_.env>
export AIRFLOW__CORE__DAGS_FOLDER=/home/constance/airflow-edge-demo/dags
```

**Important**: The `.env` file uses `AIRFLOW_JWT_SECRET` (no double underscores). Docker Compose maps this to `AIRFLOW__API_AUTH__JWT_SECRET`. On the Pi, you must set `AIRFLOW__API_AUTH__JWT_SECRET` directly — same value, different env var name.

### Start

```bash
airflow edge worker -q raspberry_pi -c 1
```

### DAG files

Must be available locally on the Pi. For the demo, `rsync` or `git clone` the `dags/` folder. Point `AIRFLOW__CORE__DAGS_FOLDER` to wherever they live.

## Task Routing

Queue-based. Tasks specify which edge queue they target:

```python
@task(executor="edge3", queue="raspberry_pi")
def update_led_panel(status: str):
    ...
```

The edge worker starts with `-q raspberry_pi` and only picks up tasks on that queue.

## Configuration Reference

| Setting | Default | Description |
|---|---|---|
| `AIRFLOW__EDGE__API_ENABLED` | `False` | Enable the edge API endpoint on the server |
| `AIRFLOW__EDGE__API_URL` | `None` | URL the worker uses to reach the edge API |
| `AIRFLOW__EDGE__HEARTBEAT_INTERVAL` | `30` | Seconds between worker heartbeats |
| `AIRFLOW__EDGE__JOB_POLL_INTERVAL` | `5` | Seconds between polls for new jobs |
| `AIRFLOW__EDGE__WORKER_CONCURRENCY` | `8` | Max parallel tasks (set to 1 for Pi Zero) |
| `AIRFLOW__EDGE__PUSH_LOG_CHUNK_SIZE` | `524288` | Log upload chunk size in bytes |

## Pi Zero 2 W Considerations

- **512MB RAM** is tight for a full Airflow install. Use a 2GB swap file.
- Set `worker_concurrency=1` to minimize memory.
- Pre-install everything before the demo — don't install at the conference.
- Keep the task lightweight (subprocess call to the C++ LED binary, not heavy Python imports).
- **Version matching is critical**: the Edge Worker auto-shuts down if its Airflow or edge provider version differs from the API server.
- **Fallback**: If Airflow won't fit on the Pi, fall back to SSH-based task execution from Airflow (less impressive but works).
