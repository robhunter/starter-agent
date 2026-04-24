#!/bin/bash
# scripts/log-event.sh — Log a structured event to logs/events.jsonl
# Provides the timestamp automatically so the caller doesn't need to.
#
# Usage:
#   bash scripts/log-event.sh <type> <summary> [project]
#
# Examples:
#   bash scripts/log-event.sh work "Finished draft of the Q2 plan"
#   bash scripts/log-event.sh error "Failed to reach external API" research
#
# Valid types: work, error, dissonance
# (cycle_start and cycle_end are logged by the framework's wake.sh)

set -e

AGENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$AGENT_DIR/logs/events.jsonl"

TYPE="${1:?Usage: log-event.sh <type> <summary> [project]}"
SUMMARY="${2:?Usage: log-event.sh <type> <summary> [project]}"
PROJECT="${3:-}"

TS="$(date -Iseconds)"

mkdir -p "$AGENT_DIR/logs"

if [ -n "$PROJECT" ]; then
  echo "{\"ts\":\"${TS}\",\"type\":\"${TYPE}\",\"summary\":\"${SUMMARY}\",\"project\":\"${PROJECT}\"}" >> "$LOG_FILE"
else
  echo "{\"ts\":\"${TS}\",\"type\":\"${TYPE}\",\"summary\":\"${SUMMARY}\"}" >> "$LOG_FILE"
fi
