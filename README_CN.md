# 🛡️ Process Guardian

**别让AI启动的后台进程悄悄死掉。**

专为AI编程代理设计的进程管理框架 — [Claude Code](https://docs.anthropic.com/en/docs/claude-code)、[Clawdbot](https://github.com/clawdbot/clawdbot)、[OpenClaw](https://openclaw.com)，或任何会启动后台进程的AI代理。支持隔离执行、PID追踪、崩溃自动重启、主动健康告警。

[🇬🇧 English README](./README.md)

## 问题

AI代理启动后台进程时（`exec &`、`nohup` 等），进程会绑定到父会话。当会话结束 — 超时、上下文切换、清理 — 子进程收到 SIGTERM 然后悄悄死掉。**没人知道，直到你手动去问。**

我们在造这个之前，一天内遇到了3次。

## 解决方案

一个框架管所有：

```bash
# 注册进程（一次性）
bash scripts/managed-process.sh register my-bot "python3 bot.py" 480

# 启动（完全隔离，杀不死）
bash scripts/managed-process.sh start my-bot

# 查看状态
bash scripts/managed-process.sh status
# ═══════════════════════════════════════════
#   Managed Process Status
# ═══════════════════════════════════════════
#   my-bot:
#     Status: 🟢 Running (PID 12345, uptime 2h15m)
#     Duration: 480min | Auto-restart: ✅
# ═══════════════════════════════════════════
```

## 功能

- **隔离执行** — `setsid` + `nohup` + `disown`。进程获得独立会话ID和PPID=1，父进程死亡不影响。
- **进程注册表** — `.process-registry.json` 追踪一切。没注册的进程等于不存在。
- **自动健康检查** — Cron每5分钟运行。自动检测死掉的进程。
- **自动重启** — 异常死亡？5分钟内重启。正常结束？不管它。
- **主动告警** — 写标志文件，代理心跳时捡起来通知你。
- **信号日志** — 信号处理器记录日志而不是悄悄退出的最佳实践。

## 安装

### Claude Code

克隆到项目目录 — Claude Code 会自动读取 `CLAUDE.md`：

```bash
git clone https://github.com/jzOcb/process-guardian.git
cd process-guardian
bash scripts/install.sh
```

Claude Code 会遵循 `CLAUDE.md` 中的规则，对所有后台进程使用托管框架。

### Clawdbot / OpenClaw

复制到 skills 目录 — 代理自动读取 `SKILL.md`：

```bash
cp -r process-guardian /path/to/clawd/skills/
bash skills/process-guardian/scripts/install.sh
```

### 独立使用

只要有 bash + cron 就行：

```bash
git clone https://github.com/jzOcb/process-guardian.git
cd process-guardian
bash scripts/install.sh
```

## 命令

| 命令 | 用法 | 说明 |
|------|------|------|
| `register` | `register <名称> <命令> [时长_分钟]` | 注册托管进程 |
| `start` | `start <名称>` | 隔离启动 |
| `stop` | `stop <名称>` | 优雅停止 |
| `restart` | `restart <名称>` | 停止 + 启动 |
| `status` | `status [名称]` | 查看全部/单个进程状态 |
| `healthcheck` | `healthcheck` | 检测死进程，重启，告警 |

## 原理

### 为什么进程会死

```
代理运行: exec background python3 bot.py
  └─ 创建子进程，绑定到exec会话
      └─ 会话清理（~20-30分钟后）
          └─ SIGTERM发送给所有子进程
              └─ 进程悄悄死掉
                  └─ 几小时没人知道
```

### Process Guardian 怎么解决

```
代理运行: managed-process.sh start my-bot
  └─ setsid + nohup + disown
      └─ 进程获得独立会话(SID)，PPID=1
          └─ 父进程死了，子进程活着
              └─ Cron每5分钟检查
                  └─ 如果死了 → 自动重启 + 告警
```

## 信号处理最佳实践

脚本应该**记录**信号，而不是悄悄退出：

```python
import signal
from datetime import datetime

def handler(signum, frame):
    sig_name = signal.Signals(signum).name
    print(f"⚠️ 信号: {sig_name} at {datetime.now()}", flush=True)
    # 设置标志，不要 sys.exit(0) — 那会让监控以为正常退出
    global shutdown
    shutdown = True

signal.signal(signal.SIGTERM, handler)
signal.signal(signal.SIGINT, handler)
```

## 血泪教训

这个项目的诞生是因为一个BTC交易机器人用 `exec &` 启动后，一天内死了3次。每次都是用户几小时后手动问"还好吗？"才发现。

根因：`exec` 后台进程继承父会话。AI代理会话被清理时，SIGTERM传播给所有子进程。机器人的信号处理器调用了 `sys.exit(0)`，看起来像正常退出 — 连watchdog都没重启它。

我们造了 Process Guardian，让这种事不再发生。对任何人。

## License

MIT
