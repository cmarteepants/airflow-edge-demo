"""
LED Sign DAG — monitors Zoom meeting status and updates the LED panel on Pi.

One DAG run = one complete meeting lifecycle:
  1. Wait for Zoom to start  (flag file appears)
  2. Set LED to ON AIR       (edge task on Pi)
  3. Wait for Zoom to end    (flag file disappears)
  4. Set LED to FREE         (edge task on Pi)

schedule="@continuous" + max_active_runs=1 keeps it looping indefinitely.
The zoom_monitor.py script (run natively on macOS) creates/deletes
/tmp/zoom-state/active, which is bind-mounted into the Airflow containers.
"""

import json
import os
from datetime import datetime

from airflow.sdk import PokeReturnValue, dag, task

ZOOM_FLAG = "/tmp/zoom-state/active"
LED_STATE = "/tmp/led-state.json"


@dag(
    schedule="@continuous",
    catchup=False,
    max_active_runs=1,
    start_date=datetime(2026, 3, 1),
)
def led_sign():
    @task.sensor(poke_interval=1, timeout=86400, mode="poke")
    def wait_for_meeting_start() -> PokeReturnValue:
        found = os.path.exists(ZOOM_FLAG)
        if found:
            print(f"Zoom meeting detected: {ZOOM_FLAG} exists")
        return PokeReturnValue(is_done=found)

    @task.sensor(poke_interval=1, timeout=86400, mode="poke")
    def wait_for_meeting_end() -> PokeReturnValue:
        ended = not os.path.exists(ZOOM_FLAG)
        if ended:
            print(f"Zoom meeting ended: {ZOOM_FLAG} gone")
        return PokeReturnValue(is_done=ended)

    @task(executor="edge3", queue="raspberry_pi")
    def set_on_air():
        print("Setting LED to ON AIR")
        with open(LED_STATE, "w") as f:
            json.dump({"status": "on_air"}, f)
        print(f"Written {LED_STATE}: on_air")

    @task(executor="edge3", queue="raspberry_pi")
    def set_free():
        print("Setting LED to FREE")
        with open(LED_STATE, "w") as f:
            json.dump({"status": "free"}, f)
        print(f"Written {LED_STATE}: free")

    wait_for_meeting_start() >> set_on_air() >> wait_for_meeting_end() >> set_free()


led_sign()
