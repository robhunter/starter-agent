# Setup — starter-agent

## What this is

A starter autonomous agent. Once set up, it wakes on a schedule, reads
your memory files, looks at what's on its plate, does some work (research,
file updates, notifications), and commits a journal entry.

You spend ~20 minutes up front having a conversation with it to tell it
who you are, what you want, and how you want to work together. After
that, it runs on its own.

Plan for ~1 hour end to end. Most of that is waiting for Docker to
install things.

## Prerequisites

- **Docker** — installed and running.
- **agentbox** — a wrapper around the Claude Code CLI that runs in an
  ephemeral container. Clone and follow its install instructions:
  <https://github.com/robhunter/agentbox>. Requires Bash 4+ (on macOS,
  `brew install bash`).
- A **Claude.ai** account you can OAuth with.
- A **GitHub personal access token** with `repo` scope. Used so your
  agent can commit and push from inside its container.
  <https://github.com/settings/tokens>

## 1. Clone

Pick a directory to hold your agent repos (e.g. `~/agents`). `starter-agent`
and `agent-portal` need to sit as sibling directories — `docker-create.sh`
resolves `agent-portal` relative to your agent's location.

```bash
mkdir -p ~/agents && cd ~/agents
git clone https://github.com/robhunter/starter-agent.git
git clone https://github.com/robhunter/agent-portal.git
```

## 2. Create your `.env` file

The agent container needs secrets for Git and GitHub. Create
`starter-agent/.env` (this file is gitignored — it stays on your machine):

```bash
cd starter-agent
cat > .env <<'EOF'
GH_TOKEN=ghp_your_github_token_here
GIT_AUTHOR_NAME=Your Name
GIT_AUTHOR_EMAIL=you@example.com
GIT_COMMITTER_NAME=Your Name
GIT_COMMITTER_EMAIL=you@example.com
EOF
```

Fill in your real token and identity. The commit identity will appear on
every commit your agent makes.

## 3. Onboarding conversation

From inside the `starter-agent` directory, start Claude in an ephemeral
agentbox container:

```bash
agentbox
```

Claude will greet you and start a 15-25 minute conversation covering four
topics: who you are, what you're interested in, what you want help with,
and how you want to work together. Answer naturally — full sentences in
your own words. There are no forms or multiple choice.

At the end, Claude will summarize what it heard, ask for any corrections,
then write the answers to `memory/*.yaml` and commit. You'll see a
commit message like `chore: onboarding complete — populated memory and
config for <name>`.

Exit agentbox (`Ctrl-D` or `exit`).

**If you want to pause mid-conversation**: tell Claude "I need to pause"
and it will commit what it has so far. Re-run `agentbox` later to pick up
where you left off.

## 4. Launch the persistent agent

Still inside the `starter-agent` directory on the host:

```bash
bash ../agent-portal/scripts/docker-create.sh .
```

This creates a long-running Docker container named after your agent (the
name you picked during onboarding). It installs system packages, clones
the framework, installs Node.js, sets up cron, and starts the web
portal. Expect 2-5 minutes.

## 5. Authenticate Claude

The container needs a Claude.ai OAuth login. Your agent's name is in
`agent.yaml`:

```bash
grep '^name:' agent.yaml
```

Use that name in the command below:

```bash
docker exec -it <agent-name> bash -c 'source ~/.nvm/nvm.sh && claude /login'
```

This opens a URL. Visit it in your browser, complete OAuth, paste the
code back. Done once — survives container restarts.

## 6. Verify

```bash
# Container is alive
docker ps -f name=<agent-name>

# Portal UI (port is 8080 unless you changed it in agent.yaml)
open http://localhost:8080
```

The portal shows your agent's journal, outputs, and status. The first
cycle fires on the cron schedule in `agent.yaml` (default: every 2
hours). To trigger one manually without waiting:

```bash
docker exec <agent-name> bash /root/workspaces/agent-portal/scripts/wake.sh /root/<agent-name>
```

Watch the portal — a journal entry should appear within a few minutes.

## What next

- **Change priorities.** Edit `today.md` directly; the next cycle reads it.
- **Change memory.** Edit `memory/*.yaml` directly (your values, projects,
  persona). Next cycle reads them.
- **Stop the agent.** `docker stop <agent-name>`.
- **Restart the agent.** `docker start <agent-name>`.
- **Rebuild from scratch.** `docker rm -f <agent-name>` and re-run step 4.
  Your memory and journals survive because they live in the host repo
  (which is mounted into the container).

## Troubleshooting

- **Port 8080 already in use.** Edit `agent.yaml` (`port:`) and
  `portal.config.json` (`port:`), then rebuild the container (step 4).
- **Claude CLI not authenticated.** Re-run step 5.
- **Cron not firing.** `docker exec <agent-name> crontab -l` shows the
  schedule. `docker logs <agent-name>` shows recent activity.
- **`.env` not found.** `docker-create.sh` requires `.env` in the agent
  directory. See step 2.
- **Lost track of the agent name.** `cat agent.yaml | grep '^name:'`.
- **Onboarding kicked off again unexpectedly.** Mode detection triggers
  only on `status: uninitialized` in `memory/persona.yaml`. If that
  sentinel is still there, onboarding wasn't fully completed — run
  `agentbox` and finish the conversation.

## Optional: host dashboard (flenderson)

If you end up running multiple agents, flenderson gives you a
host-level dashboard across all of them. Skip this for your first agent;
it's easy to add later.

<https://github.com/robhunter/flenderson>
