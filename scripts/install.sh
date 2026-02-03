#!/bin/bash
# Install process-guardian: set up cron healthcheck and directories
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="${WORKSPACE:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
MANAGED_PROCESS="$SCRIPT_DIR/managed-process.sh"

echo "═══════════════════════════════════════════"
echo "  Process Guardian — Install"
echo "═══════════════════════════════════════════"

# Create directories
mkdir -p /tmp/managed-processes/logs
echo "✅ Created /tmp/managed-processes/"

# Initialize registry if missing
REGISTRY="$WORKSPACE/.process-registry.json"
if [ ! -f "$REGISTRY" ]; then
    echo '{}' > "$REGISTRY"
    echo "✅ Created $REGISTRY"
else
    echo "✅ Registry exists: $REGISTRY"
fi

# Make script executable
chmod +x "$MANAGED_PROCESS"
echo "✅ Made managed-process.sh executable"

# Add cron healthcheck (remove old one first, then add)
CRON_CMD="*/5 * * * * bash $MANAGED_PROCESS healthcheck >> /tmp/managed-processes/logs/healthcheck.log 2>&1"
(crontab -l 2>/dev/null | grep -v "managed-process.sh healthcheck"; echo "$CRON_CMD") | crontab -
echo "✅ Cron healthcheck added (every 5 min)"

echo ""
echo "═══════════════════════════════════════════"
echo "  Installation complete!"
echo ""
echo "  Usage:"
echo "    bash $MANAGED_PROCESS register <name> <command> [duration_min]"
echo "    bash $MANAGED_PROCESS start <name>"
echo "    bash $MANAGED_PROCESS status"
echo "═══════════════════════════════════════════"
