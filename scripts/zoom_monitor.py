#!/usr/bin/env python3
"""
Zoom meeting status monitor for macOS.

Creates /tmp/zoom-state/active when a Zoom meeting starts (CptHost process
is running). Deletes it when the meeting ends. Docker bind-mounts
/tmp/zoom-state/ into Airflow containers so the DAG can detect changes.

Run natively on macOS (not in Docker):
  python3 scripts/zoom_monitor.py
"""

import os
import subprocess
import time

STATE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "zoom-state")
FLAG_FILE = os.path.join(STATE_DIR, "active")
POLL_INTERVAL = 2  # seconds


def is_in_meeting() -> bool:
    result = subprocess.run(["pgrep", "-x", "CptHost"], capture_output=True)
    return result.returncode == 0


def main():
    print(f"Zoom monitor started. Flag file: {FLAG_FILE}")

    last_status = None
    while True:
        in_meeting = is_in_meeting()

        if in_meeting != last_status:
            if in_meeting:
                open(FLAG_FILE, "w").close()
                print("Meeting started → created flag file")
            else:
                if os.path.exists(FLAG_FILE):
                    os.remove(FLAG_FILE)
                print("Meeting ended → deleted flag file")
            last_status = in_meeting

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
