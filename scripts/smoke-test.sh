#!/bin/bash
# scripts/smoke-test.sh — Structural smoke test (Mode A) for starter-agent.
#
# Validates the onboarding plumbing end-to-end in a fresh clone: mode
# detector, YAML templates, sentinel replacement, wrapper scripts, and
# commit.sh. Does NOT attempt a live agentbox conversation (that's Mode B,
# a separate manual exercise).
#
# Usage (from a throwaway clone):
#   git clone https://github.com/robhunter/starter-agent.git /tmp/starter-agent-test
#   cd /tmp/starter-agent-test
#   bash scripts/smoke-test.sh
#
# Prerequisites: git, a python with PyYAML (set $PYTHON to pick a specific
# interpreter; defaults to python3 and auto-falls-back to the memory-venv
# python at /root/workspaces/agent-portal/scripts/memory-venv/bin/python
# when available), node (for commit.sh's read-config.js), and the
# agent-portal framework cloned at /root/workspaces/agent-portal (the
# in-agentbox/in-container path).
#
# The script mutates the clone (populates memory files, replaces sentinels,
# creates a commit) and does NOT clean up — throw the clone away afterwards.
# It aborts if persona.yaml's uninitialized sentinel is already gone, to
# avoid false positives on an already-populated repo.

set -u

AGENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$AGENT_DIR"

PASS=0
FAIL=0
FAILED_CHECKS=()

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}
fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
  FAILED_CHECKS+=("$1")
}

header() {
  echo
  echo "=== $1 ==="
}

# ---------------------------------------------------------------------------
header "Preflight"

# Pick a python with PyYAML. Honors $PYTHON, then tries python3, then the
# memory-venv path we know about from agent-coder's environment.
PYTHON="${PYTHON:-}"
if [ -n "$PYTHON" ] && "$PYTHON" -c "import yaml" 2>/dev/null; then
  :
elif command -v python3 >/dev/null && python3 -c "import yaml" 2>/dev/null; then
  PYTHON=python3
elif [ -x /root/workspaces/agent-portal/scripts/memory-venv/bin/python ] \
     && /root/workspaces/agent-portal/scripts/memory-venv/bin/python -c "import yaml" 2>/dev/null; then
  PYTHON=/root/workspaces/agent-portal/scripts/memory-venv/bin/python
else
  fail "no python with PyYAML found (set \$PYTHON, or pip install pyyaml)"
  exit 1
fi
pass "python with PyYAML: $PYTHON"

case "$PWD" in
  */workspaces/starter-agent|*/agents/starter-agent)
    echo "  ABORT: refusing to run in the canonical workspace ($PWD)."
    echo "         This test mutates files and creates a commit. Run it in a throwaway clone:"
    echo "           git clone https://github.com/robhunter/starter-agent.git /tmp/starter-agent-test"
    echo "           cd /tmp/starter-agent-test && bash scripts/smoke-test.sh"
    exit 1
    ;;
esac
pass "CWD is not a canonical workspace path"

if ! grep -q '^status: uninitialized' memory/persona.yaml; then
  echo "  ABORT: memory/persona.yaml is already populated (no uninitialized sentinel)."
  echo "         Run this test in a fresh clone."
  exit 1
fi
pass "repo is in pristine uninitialized state"

# ---------------------------------------------------------------------------
header "Step 0: as-shipped artifacts are structurally valid"

# These checks run against the COMMITTED templates before the later steps
# mutate them (Step 2 overwrites the memory yamls; Step 4 replaces the
# sentinels in agent.yaml + portal.config.json). They catch corruption in
# the exact files a friend clones — a launch-blocker the behavioral steps
# would mask, because they rewrite those same files before validating them.

# 0a — every memory template parses as YAML and ships with the onboarding
#      sentinel. ONBOARDING.md's resume logic ("skip to the first topic whose
#      yaml is still status: uninitialized") relies on ALL four templates
#      shipping uninitialized, not just persona.yaml (which the mode detector
#      keys on). A template missing the sentinel would silently skip its topic.
for f in memory/human.yaml memory/values.yaml memory/projects.yaml memory/persona.yaml; do
  if "$PYTHON" -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
    pass "$f parses as shipped"
  else
    fail "$f does not parse as shipped"
  fi
  if grep -q '^status: uninitialized' "$f"; then
    pass "$f ships the uninitialized sentinel"
  else
    fail "$f is missing the uninitialized sentinel (onboarding resume precondition)"
  fi
done

# 0b — config templates parse as shipped, with the STARTER_AGENT_NAME sentinel
#      still present (pre-replacement). agent.yaml is read by the framework on
#      every wake; portal.config.json is read by the portal server on boot. A
#      syntax error here bricks the friend's first run before onboarding starts.
if "$PYTHON" -c "import yaml; yaml.safe_load(open('agent.yaml'))" 2>/dev/null; then
  pass "agent.yaml parses as shipped (sentinel present)"
else
  fail "agent.yaml does not parse as shipped"
fi
if "$PYTHON" -c "import json; json.load(open('portal.config.json'))" 2>/dev/null; then
  pass "portal.config.json parses as shipped (sentinel present)"
else
  fail "portal.config.json does not parse as shipped"
fi

# 0c — every shipped shell script is syntactically valid. The friend's cycles
#      shell out to these wrappers (commit.sh, log-event.sh, log-journal.sh,
#      start.sh); a syntax error fails the cycle, often silently under cron.
for s in scripts/*.sh; do
  if bash -n "$s" 2>/dev/null; then
    pass "$(basename "$s") passes bash -n syntax check"
  else
    fail "$(basename "$s") has a bash syntax error"
  fi
done

# ---------------------------------------------------------------------------
header "Step 1: mode detector triggers onboarding on pristine clone"

grep -q '^status: uninitialized' memory/persona.yaml \
  && pass "grep finds 'status: uninitialized' in memory/persona.yaml" \
  || fail "mode detector grep did not match uninitialized sentinel"

# ---------------------------------------------------------------------------
header "Step 2: simulate onboarding writes — all four memory yamls parse"

cat > memory/human.yaml <<'EOF'
name: Priya
location: Bangalore
current_status: |
  Founder exploring AI agents
career_history:
  - role: Engineer
    company: Acme
    period: "2020-2024"
skills:
  technical:
    - Python
  leadership: []
schedule_patterns: mornings
free_form_notes: |
  Prefers async.
EOF

cat > memory/values.yaml <<'EOF'
core:
  - honesty
interests:
  - AI
  - startups
explicit_preferences:
  - concise over verbose
EOF

cat > memory/projects.yaml <<'EOF'
projects:
  - name: agent-research
    description: exploring AI agent patterns
    url: ""
    mode: explore
EOF

cat > memory/persona.yaml <<'EOF'
name: testbot
role: smoke-test agent
style:
  communication: concise
  reporting: daily
  initiative: medium
notification_thresholds:
  notify_when:
    - blocker encountered
  stay_quiet_when:
    - routine progress
EOF

for f in memory/human.yaml memory/values.yaml memory/projects.yaml memory/persona.yaml; do
  if "$PYTHON" -c "import yaml,sys; yaml.safe_load(open('$f'))" 2>/dev/null; then
    pass "$f parses"
  else
    fail "$f did not parse"
  fi
done

# ---------------------------------------------------------------------------
header "Step 3: mode detector stops triggering after persona.yaml populated"

grep -q '^status: uninitialized' memory/persona.yaml \
  && fail "mode detector still matches after populating persona.yaml" \
  || pass "grep stops matching after persona.yaml is populated"

# ---------------------------------------------------------------------------
header "Step 4: sentinel replacement — STARTER_AGENT_NAME → testbot"

sed -i 's/STARTER_AGENT_NAME/testbot/g' agent.yaml portal.config.json

REMAINING=$(grep -c STARTER_AGENT_NAME agent.yaml portal.config.json 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')
if [ "$REMAINING" = "0" ]; then
  pass "zero STARTER_AGENT_NAME matches remain"
else
  fail "$REMAINING STARTER_AGENT_NAME matches still remain"
fi

if "$PYTHON" -c "import yaml; yaml.safe_load(open('agent.yaml'))" 2>/dev/null; then
  pass "agent.yaml parses after replacement"
else
  fail "agent.yaml did not parse after replacement"
fi

if "$PYTHON" -c "import json; json.load(open('portal.config.json'))" 2>/dev/null; then
  pass "portal.config.json parses after replacement"
else
  fail "portal.config.json did not parse after replacement"
fi

# ---------------------------------------------------------------------------
header "Step 5a: scripts/log-event.sh emits valid JSON"

bash scripts/log-event.sh work "smoke test" starter-agent
if [ -f logs/events.jsonl ]; then
  LAST=$(tail -1 logs/events.jsonl)
  if "$PYTHON" -c "
import json,sys
d = json.loads('''$LAST''')
assert d['type']=='work', 'type wrong'
assert d['summary']=='smoke test', 'summary wrong'
assert d['project']=='starter-agent', 'project wrong'
" 2>/dev/null; then
    pass "logs/events.jsonl last entry is valid work event"
  else
    fail "logs/events.jsonl last entry did not validate: $LAST"
  fi
else
  fail "logs/events.jsonl was not created"
fi

# ---------------------------------------------------------------------------
header "Step 5b: scripts/log-journal.sh writes with runtime-read author"

bash scripts/log-journal.sh note "smoke test"
YYYY_MM=$(date +%Y-%m)
if [ -f "journals/$YYYY_MM.md" ]; then
  if grep -q '| testbot | note' "journals/$YYYY_MM.md"; then
    pass "journal entry author is 'testbot' (runtime-read from agent.yaml)"
  else
    fail "journal entry author is NOT 'testbot' — runtime-read broken"
  fi
else
  fail "journals/$YYYY_MM.md was not created"
fi

# ---------------------------------------------------------------------------
header "Step 5c: scripts/commit.sh creates a commit (push may warn)"

# Unset GH_TOKEN so commit.sh takes the no-token path — matches a friend's
# first-time environment (they haven't set .env on the host yet).
GIT_HEAD_BEFORE=$(git rev-parse HEAD)
if env -u GH_TOKEN bash scripts/commit.sh "test: smoke test commit" >/tmp/smoke-commit.log 2>&1; then
  GIT_HEAD_AFTER=$(git rev-parse HEAD)
  if [ "$GIT_HEAD_BEFORE" != "$GIT_HEAD_AFTER" ]; then
    pass "commit.sh created a new commit ($GIT_HEAD_AFTER)"
  else
    fail "commit.sh exited 0 but no new commit was created"
  fi
else
  fail "commit.sh exited non-zero (see /tmp/smoke-commit.log)"
fi

# ---------------------------------------------------------------------------
header "Summary"

echo "  Passed: $PASS"
echo "  Failed: $FAIL"

if [ $FAIL -eq 0 ]; then
  echo
  echo "SMOKE TEST PASSED — plumbing works end-to-end."
  exit 0
else
  echo
  echo "SMOKE TEST FAILED — $FAIL check(s):"
  for c in "${FAILED_CHECKS[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
