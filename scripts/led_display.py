#!/usr/bin/env python3
"""
Persistent LED display service for the PyCascades 2026 demo.

Watches ~/led-state.json and drives a 64x32 RGB LED matrix panel.
Airflow tasks write to the state file; this service reads it and updates the display.

States:
  - "on_air": "ON AIR" in red on black, with a blinking red dot (~1Hz)
  - "free":   "FREE" in green on black

Run with sudo (GPIO access required):
  sudo python3 ~/airflow-edge-demo/scripts/led_display.py
"""

import json
import os
import time

from rgbmatrix import RGBMatrix, RGBMatrixOptions, graphics

# --- Configuration ---

PI_USER_HOME = "/home/constance"
STATE_FILE = (
    "/tmp/led-state.json"  # must be outside /home — RGBMatrix drops to uid 1 after init
)
FONT_DIR = os.path.join(PI_USER_HOME, "rpi-rgb-led-matrix/fonts")
POLL_INTERVAL = 0.5  # seconds — also controls blink rate (~1Hz)

# Panel hardware settings (must match hardware.md)
ROWS = 32
COLS = 64
GPIO_SLOWDOWN = 4
GPIO_MAPPING = "adafruit-hat"


def create_matrix():
    """Initialize the RGB matrix with our hardware configuration."""
    options = RGBMatrixOptions()
    options.rows = ROWS
    options.cols = COLS
    options.gpio_slowdown = GPIO_SLOWDOWN
    options.hardware_mapping = GPIO_MAPPING
    options.disable_hardware_pulsing = True  # --led-no-hardware-pulse
    return RGBMatrix(options=options)


def read_state():
    """Read the current status from the state file. Defaults to 'free' if missing/invalid."""
    try:
        with open(STATE_FILE) as f:
            data = json.load(f)
        return data.get("status", "free")
    except (FileNotFoundError, json.JSONDecodeError, KeyError):
        return "free"


def draw_border(canvas, r, g, b):
    """Draw a 1px border around the panel edge."""
    for x in range(COLS):
        canvas.SetPixel(x, 0, r, g, b)
        canvas.SetPixel(x, ROWS - 1, r, g, b)
    for y in range(ROWS):
        canvas.SetPixel(0, y, r, g, b)
        canvas.SetPixel(COLS - 1, y, r, g, b)


def draw_on_air(canvas, font, dot_visible):
    """Draw 'ON AIR' in red with an optional blinking dot to the left."""
    draw_border(canvas, 255, 0, 0)

    text_x = 12
    text_y = 21

    # Draw "ON" and "AIR" separately with a narrower gap than the default space
    red = graphics.Color(255, 0, 0)
    x_after_on = graphics.DrawText(canvas, font, text_x, text_y, red, "ON")
    graphics.DrawText(canvas, font, text_x + x_after_on + 5, text_y, red, "AIR")

    # Blinking dot: small filled circle, vertically centered with text
    if dot_visible:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if dx * dx + dy * dy <= 5:
                    canvas.SetPixel(5 + dx, 15 + dy, 255, 0, 0)


def draw_free(canvas, font):
    """Draw 'FREE' in green, centered."""
    draw_border(canvas, 0, 255, 0)

    text_x = 16
    text_y = 21

    green = graphics.Color(0, 255, 0)
    graphics.DrawText(canvas, font, text_x, text_y, green, "FREE")


FADE_STEPS = 5
FADE_FRAME_TIME = 0.05  # 50ms per frame → 250ms per fade direction, 500ms total


def fade_transition(matrix, canvas, font, old_status, new_status):
    """Fade out the old state, then fade in the new state."""
    # Fade out
    for i in range(FADE_STEPS, 0, -1):
        matrix.brightness = int(100 * i / FADE_STEPS)
        canvas.Clear()
        if old_status == "on_air":
            draw_on_air(canvas, font, True)
        elif old_status == "free":
            draw_free(canvas, font)
        canvas = matrix.SwapOnVSync(canvas)
        time.sleep(FADE_FRAME_TIME)

    # Black frame
    canvas.Clear()
    canvas = matrix.SwapOnVSync(canvas)
    time.sleep(FADE_FRAME_TIME)

    # Fade in
    for i in range(1, FADE_STEPS + 1):
        matrix.brightness = int(100 * i / FADE_STEPS)
        canvas.Clear()
        if new_status == "on_air":
            draw_on_air(canvas, font, True)
        elif new_status == "free":
            draw_free(canvas, font)
        canvas = matrix.SwapOnVSync(canvas)
        time.sleep(FADE_FRAME_TIME)

    matrix.brightness = 100
    return canvas


def main():
    # Load font BEFORE creating matrix — RGBMatrix drops root privileges after
    # init, so file reads must happen while we're still root.
    font = graphics.Font()
    font.LoadFont(os.path.join(FONT_DIR, "9x18B.bdf"))

    matrix = create_matrix()
    canvas = matrix.CreateFrameCanvas()

    dot_visible = True
    last_status = None

    print(f"LED display service started. Watching {STATE_FILE}")

    while True:
        status = read_state()

        if status != last_status and last_status is not None:
            canvas = fade_transition(matrix, canvas, font, last_status, status)
            print(f"Status changed: {last_status} → {status}")
            last_status = status
            dot_visible = True
            continue

        canvas.Clear()

        if status == "on_air":
            draw_on_air(canvas, font, dot_visible)
            dot_visible = not dot_visible  # toggle every 500ms → ~1Hz blink
        elif status == "free":
            draw_free(canvas, font)
            dot_visible = True  # reset so dot starts visible on next on_air

        canvas = matrix.SwapOnVSync(canvas)

        if last_status is None and status != "off":
            print(f"Status changed: {last_status} → {status}")

        last_status = status
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
