#!/bin/bash
# scripts/log-journal.sh — Append a journal entry to journals/YYYY-MM.md
# Reads the agent's name from agent.yaml at runtime so entries are attributed
# correctly both before and after onboarding renames the agent.
#
# Usage:
#   bash scripts/log-journal.sh <tag> "content here"
#
# Examples:
#   bash scripts/log-journal.sh note "Considering new direction for project X"
#   bash scripts/log-journal.sh question "Should we expand scope?"
#
# Valid tags: cycle, output, feedback, observation, direction, note, question

set -e

AGENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
JOURNALS_DIR="$AGENT_DIR/journals"

TAG="${1:?Usage: log-journal.sh <tag> \"content\"}"
CONTENT="${2:?Usage: log-journal.sh <tag> \"content\"}"

case "$TAG" in
  cycle|output|feedback|observation|direction|note|question) ;;
  *) echo "Error: invalid tag '$TAG'. Must be one of: cycle, output, feedback, observation, direction, note, question" >&2; exit 1 ;;
esac

# Runtime-read: pick up the agent name from agent.yaml so this script works
# both before onboarding (writes as STARTER_AGENT_NAME) and after (writes as
# whatever name the user chose). More robust than a sentinel-replaced string
# that onboarding might miss.
AUTHOR="$(
  grep '^name:' "$AGENT_DIR/agent.yaml" 2>/dev/null \
    | head -1 \
    | sed 's/^name:[[:space:]]*//' \
    | sed 's/[[:space:]]*#.*//' \
    | sed 's/^["'\'']//' \
    | sed 's/["'\'']$//' \
    | sed 's/[[:space:]]*$//'
)"
AUTHOR="${AUTHOR:-agent}"

TS="$(date -Iseconds)"
YYYY_MM="$(date +%Y-%m)"
JOURNAL_FILE="$JOURNALS_DIR/$YYYY_MM.md"

mkdir -p "$JOURNALS_DIR"

if [ ! -f "$JOURNAL_FILE" ]; then
  printf '# Journal — %s\n\n---\n' "$YYYY_MM" > "$JOURNAL_FILE"
fi

printf '\n### %s | %s | %s\n%s\n' "$TS" "$AUTHOR" "$TAG" "$CONTENT" >> "$JOURNAL_FILE"
