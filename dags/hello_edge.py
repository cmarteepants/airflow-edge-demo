"""Hello Edge — validates that the edge worker on the Pi can run tasks."""

from __future__ import annotations

import platform
import socket

from airflow.sdk import DAG, task

with DAG(
    dag_id="hello_edge",
    schedule=None,
    catchup=False,
    tags=["edge", "test"],
):

    @task(executor="edge3", queue="raspberry_pi")
    def hello_from_pi():
        hostname = socket.gethostname()
        arch = platform.machine()
        print(f"Hello from {hostname} ({arch})!")
        return {"hostname": hostname, "arch": arch}

    hello_from_pi()
