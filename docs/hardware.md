# Hardware Reference

## Components (all confirmed working)

| Component | Detail |
|---|---|
| Raspberry Pi Zero 2 W | ARM Cortex-A53 quad-core 1GHz, 512MB RAM (416MB usable, GPU reserves rest). 2.5GB swap configured (512MB zram + 2GB /var/swap). |
| Adafruit RGB Matrix Bonnet | #3211, seated via hammer headers |
| LED Matrix Panel | 64x32 RGB |
| Power Supply | 5V 4A into Bonnet barrel jack |
| LED Library | `rpi-rgb-led-matrix` cloned and built from source at `~/rpi-rgb-led-matrix` |

## Network

| Property | Value |
|---|---|
| Tailscale IP | `100.92.1.2` |
| SSH user | `constance` |
| SSH key | `~/.ssh/pycascades_pi` |
| SSH alias | `airflow-demo` |

## Required LED Panel Flags

Every command to the panel must include these flags:

```
--led-rows=32 --led-cols=64 --led-slowdown-gpio=4 --led-no-hardware-pulse --led-gpio-mapping=adafruit-hat
```

## Working Test Command

```bash
sudo ~/rpi-rgb-led-matrix/examples-api-use/demo -D 0 \
  --led-rows=32 --led-cols=64 --led-slowdown-gpio=4 \
  --led-no-hardware-pulse --led-gpio-mapping=adafruit-hat
```

## Notes

- The panel requires `sudo` to access GPIO
- The Airflow edge worker task will need to run the LED commands with `sudo` (configure passwordless sudo for the LED binary/python script)
- `--led-no-hardware-pulse` and `--led-gpio-mapping=adafruit-hat` are mandatory for the Adafruit Bonnet
