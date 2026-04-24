#!/bin/bash
# scripts/commit.sh — Thin wrapper around the framework's commit.sh.
# Usage: bash scripts/commit.sh ["commit message"]

AGENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAMEWORK_DIR="/root/workspaces/agent-portal"

exec bash "${FRAMEWORK_DIR}/scripts/commit.sh" "${AGENT_DIR}" "$@"
