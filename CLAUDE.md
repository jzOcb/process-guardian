# Process Guardian

Manage long-running background processes with reliable detached execution, automatic health monitoring, auto-restart on failure, and proactive alerts.

## Rule

**ALL long-running processes MUST use `scripts/managed-process.sh`.** No exceptions.

- ❌ `python script.py &`, `nohup ... &`, direct background execution
- ✅ `bash scripts/managed-process.sh register <name> <cmd>` then `start <name>`

## Commands

```bash
# Register a process (once)
bash scripts/managed-process.sh register <name> "<command>" [duration_min]

# Start (fully detached, survives parent death)
bash scripts/managed-process.sh start <name>

# Check all processes
bash scripts/managed-process.sh status

# Stop gracefully
bash scripts/managed-process.sh stop <name>

# Restart
bash scripts/managed-process.sh restart <name>

# Health check (auto-restart dead processes) — runs via cron every 5 min
bash scripts/managed-process.sh healthcheck
```

## Setup

```bash
bash scripts/install.sh
```

## Why

Processes launched via `exec &` or `nohup` inherit the parent session. When the parent dies (session cleanup, timeout), SIGTERM kills all children. Signal handlers calling `sys.exit(0)` make crashes look like clean exits, so watchdogs don't restart.

This framework uses `setsid` + `nohup` + `disown` for true process isolation (PPID=1, own SID), plus cron-based health monitoring with auto-restart and alerts.

## Signal Handling Best Practice

```python
import signal
from datetime import datetime

def handler(signum, frame):
    sig_name = signal.Signals(signum).name
    print(f"⚠️ SIGNAL: {sig_name} at {datetime.now()}", flush=True)
    global shutdown
    shutdown = True  # Don't sys.exit(0)

signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)
```
