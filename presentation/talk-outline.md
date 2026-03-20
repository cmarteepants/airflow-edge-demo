# Airflow Beyond the Cloud: Python Workflows at the Edge

## Talk Outline — PyCascades 2026

- **Conference**: PyCascades 2026 (Vancouver, BC — March 21, 2026)
- **Duration**: 25 minutes (~22 min content + ~3 min Q&A)
- **Audience**: Python developers. No prior Airflow experience required.

---

## 1. Title + Bio (1 min)

**Slides 1–2**

**Slide 1 — Title:** "Airflow Beyond the Cloud: Python Workflows at the Edge." Speaker info, conference, date, hardware badges (Airflow 3, Edge Executor, Pi Zero 2 W, 64x32 LED).

**Slide 2 — Bio:** Name, role, Astronomer one-liner. Python comment: "# I built an enterprise-grade workflow orchestrator solution to tell my family I'm on a Zoom call."

**Speaker notes:** 30 seconds max on bio. The comment line sets the tone — self-aware, fun. Move quickly to the photo.

---

## 2. Hook — "I Have a Problem" (1 min)

**Slide 3**

Full-bleed photo of the home office with the ON AIR sign lit up in red. Overlay text: "I may have over-engineered it."

**Key points:**
- "I work from home. My family has no idea if I'm on a Zoom call. They walk in, the dog barks, chaos."
- "So I built a sign. And because I'm a PM for a workflow orchestrator... I may have over-engineered it."
- "It's powered by Apache Airflow, running on a Raspberry Pi Zero."
- Let the absurdity land. $15 computer, enterprise orchestrator, LED sign.

**Speaker notes:** Let the photo breathe for a beat. The self-awareness IS the joke — don't explain it, just let people laugh.

---

## 3. What Is Airflow? — 60-Second Primer (2 min)

**Slides 4–5**

**Slide 4 — What is Airflow?** DAG diagram: `extract() » transform() » load()`. Caption: "Python functions, wired into a DAG, scheduled automatically. 40k+ GitHub stars."

**Slide 5 — The Stereotype:** Badges (Snowflake, BigQuery, dbt, S3, Spark, Redshift). Then the pivot: "But what if the task you need to run isn't in the cloud?"

**Speaker notes:** Don't go deep on Airflow internals. Just: it's Python, it runs tasks in order, it's popular. The pivot question is the turn of the talk — let it breathe.

---

## 4. What Changed in Airflow 3 — Edge Executor (2 min)

**Slide 6**

Diagram: Airflow Server ← HTTPS → Edge Worker. "Got anything for me?" Pull, not push.

**Key points:**
- Edge Executor: run tasks on remote machines over HTTPS.
- Pull-based — no inbound ports, no broker, no Kubernetes.
- Multi-executor routing — one DAG, tasks on different executors.
- "If your device can make an HTTPS request, it can be an edge worker."

**Speaker notes:** Emphasize what's NOT needed: no Kafka, no RabbitMQ, no Kubernetes. The Pi reaches out.

---

## 5. The Demo Concept — What We're About to See (2 min)

**Slides 7–8**

**Slide 7 — Architecture diagram:** Two-column flow. Left (Laptop/Docker): zoom_monitor.py → flag file → Airflow Sensor → Scheduler. Right (Pi): Edge Worker → LED Service → ON AIR / FREE / PYCASCADES. Connected by HTTPS arrow (Pi pulls).

**Slide 8 — Hardware photo:** Wide shot of the 64x32 RGB LED panel. Caption: "Raspberry Pi Zero 2 W + 64x32 RGB LED panel."

**Speaker notes:** Walk through each component in the architecture. Point at the HTTPS arrow: "The Pi pulls. No inbound connections." Keep the hardware slide brief (~30s) — they'll see it live.

---

## 6. Live Demo (4.5 min)

**Slide 9** — "LIVE DEMO" backdrop with pulsing red dot.

### Sequence

1. **Show the sign** (~30s) — Idle state, "PYCASCADES" in dim blue.
2. **Show the Airflow UI** (~30s) — DAG view, sensor poking.
3. **Start the Zoom call** (~45s) — Join a pre-arranged meeting. Narrate the detection process.
4. **Watch the transition** (~30s) — Sign goes red "ON AIR". Audience reaction moment. ~3–4 seconds latency.
5. **LED code aside** (~15s) — "About 200 lines of Python using rpi-rgb-led-matrix. It's in the repo."
6. **Show Airflow UI again** (~30s) — `set_on_air` complete, `wait_for_meeting_end` running.
7. **Leave the Zoom call** (~30s) — Sign goes green "FREE".
8. **Backup plan** (~mention) — `demo sim start` / `demo sim end` if Zoom is uncooperative.

**Speaker notes:** Fill the 3–4 second latency gap with narration. If something breaks, use the sim script without apology. Keep energy high.

---

## 7. How It Works — The Python (5 min)

**Slides 10–13**

**Slide 10 — DAG Structure (1.5 min):** `@continuous` + `max_active_runs=1` = event loop. Four tasks: wait, act, wait, act. 63 lines total.

**Slide 11 — Multi-Executor Routing (1.5 min):** Side-by-side: sensor (LocalExecutor, laptop) vs edge task (EdgeExecutor, Pi). "Two keyword arguments. Two machines."

**Slide 12 — Zoom Detection (1 min):** The entire function: `subprocess.run(["pgrep", "-x", "CptHost"])`. "No API key. No OAuth. Just pgrep." This gets a laugh.

**Slide 13 — State File Pattern (1 min):** Diagram: Airflow Task → State File → LED Service. Close-up photo of the Pi + bonnet on the right. "Airflow tasks should be ephemeral. If your task can't finish, decouple."

---

## 8. Lessons and Patterns (2.5 min)

**Slides 14–15** (split across two slides)

**Slide 14 — Design Principles:**
1. **Pull beats push** for constrained environments. No open ports, no VPN. Works behind NAT, on conference WiFi.
2. **Simple beats clever.** pgrep over Zoom API. Flag file over Kafka. The dumbest thing that works is the most reliable thing on stage.

**Slide 15 — Practical Realities:**
3. **Decouple** tasks from resources they can't own. Write state, exit. Let a separate service hold the hardware.
4. **Airflow on a Pi is... a lot.** 416MB RAM + swap. It works, but a thin edge runtime is a known gap.

**Speaker notes:** Be honest about limitations. The "barely" on the Pi is endearing. The audience respects honesty over polish.

---

## 9. What Else Could You Do? — The Bigger Picture (2 min)

**Slide 16**

Single row of icons: Factory, Greenhouse, Retail, Home, Field, LED Sign (highlighted in copper).

Closing line: "Workflows don't always live in the cloud. Sometimes the work is out there — in a factory, in a greenhouse, in a closet next to an LED sign."

**Speaker notes:** Keep it aspirational, not prescriptive. You're planting seeds. End on the LED sign as the humble entry — callback to the talk.

---

## 10. Wrap-Up (1 min)

**Slide 17**

"Thank You" with: repo URL (github.com/cmarteepants/airflow-edge-demo), QR code, pip install command, speaker name, conference badges.

**Speaker notes:** One sentence callback: "Airflow beyond the cloud — it's a Raspberry Pi, an LED sign, and 63 lines of Python." Leave this slide up during Q&A.

---

## Q&A (~3 min)

**Likely questions to prep for:**

- **"Does the edge worker work on other devices?"** → Yes, anything that runs Python 3.9+ and can make HTTPS calls. ARM, x86, whatever.
- **"What about security?"** → JWT tokens. HTTPS. Tailscale adds network-layer encryption.
- **"Could this work without Tailscale?"** → Yes — any network where the Pi can reach the Airflow API. Tailscale just handles NAT traversal.
- **"Why not MQTT / Home Assistant / Node-RED?"** → Totally valid for home automation! Airflow's value is when you want DAGs, retries, logging, monitoring applied to physical systems.
- **"Is the edge worker production-ready?"** → It's new. It works. The "thin worker" vision in AIP-69 is the next step.

---

## Timing Summary

| # | Section | Slides | Time | Cumulative |
|---|---------|--------|------|-----------|
| 1 | Title + Bio | 1–2 | 1 min | 1:00 |
| 2 | Hook | 3 | 1 min | 2:00 |
| 3 | What is Airflow? | 4–5 | 2 min | 4:00 |
| 4 | Edge Executor | 6 | 2 min | 6:00 |
| 5 | Architecture + Hardware | 7–8 | 2 min | 8:00 |
| 6 | Live demo | 9 | 4.5 min | 12:30 |
| 7 | Code walkthrough | 10–13 | 5 min | 17:30 |
| 8 | Lessons | 14–15 | 2.5 min | 20:00 |
| 9 | Bigger picture | 16 | 2 min | 22:00 |
| 10 | Wrap-up | 17 | 1 min | 23:00 |
| — | Q&A | — | ~3 min | 26:00 |

**Buffer: ~1 minute before Q&A if needed.**

## Slide Count: 17

| Section | Slides |
|---------|--------|
| Title + Bio | 2 |
| Hook (photo) | 1 |
| What is Airflow | 2 |
| Edge Executor | 1 |
| Architecture + Hardware | 2 |
| Live demo | 1 |
| Code walkthrough | 4 |
| Lessons | 2 |
| Bigger picture | 1 |
| Wrap-up | 1 |
| **Total** | **17** |

## Files

- `presentation/slides.html` — Primary deck (self-contained, offline-safe, fonts inlined)
- `presentation/slides.pptx` — Backup deck (screenshot-based, with speaker notes)
- `presentation/assets/` — Source photos (referenced by HTML, not needed for PPTX)
