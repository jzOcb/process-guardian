# 🛡️ Process Guardian

**Never let AI-launched background processes die silently again.**

A managed process framework for [Clawdbot](https://github.com/clawdbot/clawdbot) / [OpenClaw](https://openclaw.com) agents. Handles detached execution, PID tracking, auto-restart on failure, and proactive health alerts.

## The Problem

When AI agents launch background processes (`exec &`, `nohup`, etc.), those processes are tied to the parent session. When the session ends — timeout, context switch, cleanup — child processes receive SIGTERM and die silently. **Nobody knows until someone manually checks.**

This happened to us 3 times in one day before we built this.

## The Solution

One framework to rule them all:

```bash
# Register a process (once)
bash scripts/managed-process.sh register my-bot "python3 bot.py" 480

# Start it (fully detached, survives everything)
bash scripts/managed-process.sh start my-bot

# Check status
bash scripts/managed-process.sh status
# ═══════════════════════════════════════════
#   Managed Process Status
# ═══════════════════════════════════════════
#   my-bot:
#     Status: 🟢 Running (PID 12345, uptime 2h15m)
#     Duration: 480min | Auto-restart: ✅
# ═══════════════════════════════════════════
```

## Features

- **Detached Execution** — `setsid` + `nohup` + `disown`. Processes get their own session ID and PPID=1. Immune to parent death.
- **Process Registry** — `.process-registry.json` tracks everything. If it's not registered, it doesn't exist.
- **Auto Health Check** — Cron runs every 5 min. Detects dead processes automatically.
- **Auto Restart** — Premature death? Restarted within 5 minutes. Completed normally? Left alone.
- **Proactive Alerts** — Writes flag files for your agent's heartbeat to pick up and notify you.
- **Signal Logging** — Best practices for signal handlers that log instead of silently exiting.

## Install

### As a Clawdbot Skill

```bash
# Copy to your skills directory
cp -r process-guardian /path/to/clawd/skills/

# Run install
bash skills/process-guardian/scripts/install.sh
```

### Standalone

```bash
git clone https://github.com/jzOcb/process-guardian.git
cd process-guardian
bash scripts/install.sh
```

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `register` | `register <name> <command> [duration_min]` | Define a managed process |
| `start` | `start <name>` | Launch fully detached |
| `stop` | `stop <name>` | Graceful shutdown |
| `restart` | `restart <name>` | Stop + start |
| `status` | `status [name]` | Show health of all/one process |
| `healthcheck` | `healthcheck` | Auto-detect dead processes, restart, alert |

## How It Works

### Why processes die

```
Agent runs: exec background python3 bot.py
  └─ Creates child process tied to exec session
      └─ Session cleanup after ~20-30 min
          └─ SIGTERM sent to all children
              └─ Bot dies silently
                  └─ Nobody knows for hours
```

### How Process Guardian fixes it

```
Agent runs: managed-process.sh start my-bot
  └─ setsid + nohup + disown
      └─ Process gets own session (SID), PPID=1
          └─ Parent can die, process survives
              └─ Cron checks every 5 min
                  └─ If dead → auto-restart + alert
```

## Signal Handling Best Practice

Your scripts should **log** signals, not silently exit:

```python
import signal
from datetime import datetime

def handler(signum, frame):
    sig_name = signal.Signals(signum).name
    print(f"⚠️ SIGNAL: {sig_name} at {datetime.now()}", flush=True)
    # Set flag, don't sys.exit(0) — that hides crashes from watchdogs
    global shutdown
    shutdown = True

signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)
```

## Born from Pain

This project exists because a BTC trading bot launched via `exec &` died 3 times in one day. Each time, nobody knew until the user manually asked "is everything okay?" hours later.

The root cause: `exec` background processes inherit the parent session. When the AI agent's session gets cleaned up, SIGTERM propagates to all children. The bot's signal handler called `sys.exit(0)`, making it look like a clean exit — so even the watchdog didn't restart it.

We built Process Guardian so this never happens again. To anyone.

## License

MIT
