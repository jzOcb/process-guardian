---
name: process-guardian
description: Manage long-running background processes (bots, scrapers, monitors, servers) with reliable detached execution, automatic health monitoring, auto-restart on failure, and proactive alerts. Use when launching any process that should survive session disconnects, when checking process health, or when a background task keeps dying silently.
---

# Process Guardian

## The Problem

When AI agents launch background processes via `exec &` or `nohup`, those processes are tied to the parent session. When the session ends (timeout, context switch, cleanup), child processes receive SIGTERM and die silently. Nobody knows until someone manually checks.

## The Rule

**ALL long-running processes MUST go through this framework.** No exceptions.

- ❌ `python script.py &`
- ❌ `nohup python script.py &`
- ❌ `exec` with `background: true`
- ✅ `bash scripts/managed-process.sh register <name> <cmd>` then `start <name>`

## Quick Start

```bash
# 1. Register a process (once)
bash scripts/managed-process.sh register my-bot "python3 /path/to/bot.py" 480

# 2. Start it
bash scripts/managed-process.sh start my-bot

# 3. Check status
bash scripts/managed-process.sh status
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `register` | `register <name> <command> [duration_min]` | Define a managed process. Duration 0 = indefinite. |
| `start` | `start <name>` | Launch registered process (fully detached). |
| `stop` | `stop <name>` | Graceful shutdown via SIGTERM. |
| `restart` | `restart <name>` | Stop then start. |
| `status` | `status [name]` | Show all processes or one specific. |
| `healthcheck` | `healthcheck` | Check all processes, restart dead ones, send alerts. |

## Setup

Run the install script to configure cron-based health monitoring:

```bash
bash scripts/install.sh
```

This adds a cron job running `healthcheck` every 5 minutes.

## How It Works

### Detached Execution
Processes launch via `setsid` + `nohup` + `disown`, giving them:
- Own session ID (SID) — not tied to any terminal
- PPID=1 (init) — survives parent death
- Immune to SIGHUP/session cleanup

### Health Monitoring
Cron runs `healthcheck` every 5 minutes:
1. Checks each registered process is alive (PID exists)
2. If dead: checks if it completed normally (ran ≥80% of expected duration)
3. If premature death: auto-restarts and writes alert flag
4. Alert cooldown: 15 min between alerts for same issue (no spam)

### Alert Integration
When a process dies, the healthcheck writes:
- `/tmp/process_monitor_alert.flag` — trigger file
- `/tmp/process_monitor_alert.txt` — alert message

Configure your agent's heartbeat to check these files and forward alerts.

## Process Registry

All processes are tracked in `.process-registry.json`:

```json
{
  "my-bot": {
    "command": "python3 /path/to/bot.py",
    "duration_min": 480,
    "auto_restart": true,
    "max_restarts": 5,
    "restart_cooldown": 30
  }
}
```

**If a process isn't in the registry, it doesn't exist.**

## Signal Handling Best Practice

Your scripts should log signals, not silently exit:

```python
import signal
from datetime import datetime

def handler(signum, frame):
    sig_name = signal.Signals(signum).name
    print(f"⚠️ SIGNAL: {sig_name} at {datetime.now()}", flush=True)
    # Set shutdown flag, don't sys.exit()
    global shutdown
    shutdown = True

signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)
```

Never call `sys.exit(0)` in signal handlers — it makes crashes look like clean exits, preventing watchdogs from restarting.
