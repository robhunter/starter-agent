#!/bin/bash
# scripts/start.sh — Container entrypoint. Delegates to framework.
#
# On first boot (docker-create.sh), the framework hasn't been cloned yet.
# This script waits for it to appear (setup happens via docker exec),
# then delegates to the framework's start.sh. On subsequent restarts,
# the framework is already there so it starts immediately.

AGENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAMEWORK_DIR="/root/workspaces/agent-portal"

while [ ! -f "${FRAMEWORK_DIR}/scripts/start.sh" ]; do
  echo "Waiting for framework at ${FRAMEWORK_DIR}..."
  sleep 5
done

exec bash "${FRAMEWORK_DIR}/scripts/start.sh" "${AGENT_DIR}"
