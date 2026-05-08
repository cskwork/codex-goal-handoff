---
name: codex-goal-handoff
description: >-
  Use when delegating a long-horizon, multi-step engineering task to OpenAI
  Codex CLI's /goal Ralph loop with durable specs, explicit human gates, and
  verification evidence. Triggers include "codex로 위임", "codex goal",
  "/goal", "ralph loop", "long-horizon task", "long-running task 자동화",
  "delegate to codex", and "ticket to fix to deploy 자동화".
---

# Codex Goal Handoff

OpenAI Codex CLI 0.128.0+ exposes `/goal <objective>` — a persistent objective that survives sessions and runs the **Ralph Loop** (Plan → Act → Test → Review → Iterate) until the goal is achieved, paused, cleared, blocked (`unmet`), or the token budget is exhausted.

This skill **does not run the loop itself.** It packages a long-horizon workflow into the four-file durable spec Codex expects, encodes HUMAN GATEs around irreversible actions, and hands the bundle off to Codex.

**Three roles, never merged:**

- **Orchestrator** (Claude Code or you): drafts the spec, supervises gates, posts externally-visible artifacts.
- **Executor** (Codex `/goal`): runs the Ralph loop, edits code, runs validation, appends to the audit log.
- **Approver** (the human): reviews diffs/previews and writes `APPROVED:Gx` tokens at gates.

## Vocabulary (matches OpenAI Codex `/goal` documentation)

This skill uses the **exact terms** from the official objective-quality table — don't substitute synonyms (Codex prompts internally key off these words).

**Objective-level (in `Prompt.md`):**

| Term | Definition |
|---|---|
| **Scope** | Exact files / modules / surface the goal may touch. |
| **Behavior** | What must be true after the change (observable, not implementation). |
| **Non-goals** | Out-of-scope items the agent must refuse even if convenient. |
| **Verification** | Concrete commands whose green output proves the goal achieved. |

**Milestone-level (in `Plan.md`, every row):**

| Term | Definition |
|---|---|
| **Deliverable** | The artifact this milestone produces (file, commit, screenshot, build). |
| **Acceptance criteria** | The observable property the deliverable must have. |
| **Validation command** | A copy-pasteable command whose exit-0 output proves acceptance. |
| **Stop-and-fix rule** | What the agent must do when validation fails (always: fix root cause before advancing; never retry blindly more than once). |

`Prompt.md`'s `Verification` section is the **objective-level** rollup; `Plan.md`'s per-milestone `Validation command` column is the **milestone-level** evidence. The objective is verified when every milestone's validation has passed and been recorded in `Documentation.md`.

## When to use

Trigger this skill when the user wants to delegate a workflow that:

- has **3+ milestones**, each with a measurable acceptance criterion;
- will **outlive a single chat turn** (typical: 30 min – several hours of agent time);
- has a **scoped surface** (single ticket, single bounded module — not "refactor the platform");
- has at least one **irreversible action** (push, merge, deploy, public comment) that needs an explicit human approval gate.

The canonical workflow this skill ships with — `workflows/jira-bug-fix.md` — covers ticket fetch → browser reproduction → Playwright script → repo exploration → branch/fix/commit → local verify → push → merge → CI/CD deploy → re-verify → as-is/to-be PDF → ticket comment.

## When NOT to use

- **Single-turn tasks** — no loop benefit; do them inline.
- **Open-ended exploration** without a "done when" checklist — use a research/explore skill first, come back when scope is bounded.
- **Subjective tasks** with no testable Acceptance criteria ("make the API nicer").
- **High-stakes irreversible operations as the entire goal** (prod deploy, schema migration, money movement). Allow them only as **HUMAN GATE** milestones inside a larger goal — never as the autonomous payload.

## Skill lifecycle (5 phases)

### Phase 0 — First-run auto-setup (idempotent)

Run these checks once per machine. The skill does steps that are safe automatically; user is asked only for irreversible or auth-required steps.

```bash
# 1. Codex CLI version (must be ≥ 0.128.0 — first /goal release)
codex --version || { echo "Install: npm i -g @openai/codex@latest"; exit 1; }

# 2. Auto-enable the goals feature flag (idempotent; backs up first)
CFG="${CODEX_HOME:-$HOME/.codex}/config.toml"
if [ -f "$CFG" ] && ! grep -qE '^\s*goals\s*=\s*true' "$CFG"; then
  cp "$CFG" "$CFG.bak-$(date +%Y%m%d-%H%M%S)"
  if grep -qE '^\[features\]' "$CFG"; then
    awk '/^\[features\]/{print; print "goals = true"; next} {print}' "$CFG" > "$CFG.new" && mv "$CFG.new" "$CFG"
  else
    printf '\n[features]\ngoals = true\n' >> "$CFG"
  fi
  echo "Enabled features.goals = true (backup: $CFG.bak-*)"
fi

# 3. ChatGPT auth (REQUIRED — /goal persistence is tied to the ChatGPT account, not API keys)
codex login status 2>&1 | grep -qi chatgpt || {
  echo "Run: codex login   (choose 'Sign in with ChatGPT')"
  exit 1
}

# 4. Optional: codex-plugin-cc bridge (only needed if handing off from inside Claude Code)
# In Claude Code: /plugin marketplace add openai/codex-plugin-cc && /plugin install codex@openai-codex
```

If running from this skill directly, just paste the script above into the user's shell. The skill never touches `~/.codex/config.toml` without first making a timestamped `.bak-*` copy.

### Phase 1 — Collect spec inputs

Pull these from the user before writing any file. Ask only what is missing — never invent values (a wrong CI/CD job name silently deploys the wrong service).

| Slot | Example | Source |
|---|---|---|
| `TICKET_ID` | `PROJ-1234` | user / ticket URL |
| `TICKET_TYPE` | `fix` or `feat` | derived from issue type |
| `BASE_BRANCH` | `main` | user / repo convention |
| `INTEGRATION_BRANCH` | `develop` | user / repo convention |
| `REPRO_URL` | `https://staging.example.com/...` | ticket repro steps |
| `LOCAL_API` | `http://localhost:8080/api/...` | service README |
| `DEV_API` | `https://dev.example.com/api/...` | infra docs |
| `LOCAL_TEST_CMD` | `npm test`, `./gradlew :svc:test`, `pytest tests/svc/` | repo |
| `LOCAL_START_CMD` | `npm run dev`, `./gradlew bootRun` | repo |
| `CI_SYSTEM` | `jenkins` / `github-actions` / `circle` / `gitlab-ci` | infra |
| `CI_DEPLOY_TRIGGER` | `curl -X POST -u $TOK $JENKINS/job/<job>/buildWithParameters?BRANCH=develop` | CI docs |
| `CI_DEPLOY_POLL` | command returning `SUCCESS` once done | CI docs |
| `TICKET_PROVIDER` | `jira` / `linear` / `github` / `none` | user |
| `TOKEN_BUDGET` | `2_000_000` (medium goal) | see Budget table below |
| `WORKDIR` | absolute path to repo root | user / `pwd` |

If a ticket-provider MCP is available (e.g. `mcp__claude_ai_Atlassian__getJiraIssue`), fetch the issue at this phase to extract the title, repro steps, and acceptance criteria — paste the verbatim text into `Prompt.md`. Codex inside `/goal` does not have ticket-system access; pre-load primary-source text or you'll be debugging a paraphrase.

### Phase 2 — Render the four durable files

Create `${WORKDIR}/.codex-goals/${TICKET_ID}/` and render the four templates from `templates/` into it. These four files are the **single source of truth** — Codex re-reads them at every loop iteration.

| File | Sections | Mutability |
|---|---|---|
| `Prompt.md` | **Scope · Behavior · Non-goals · Verification** + Done-when checklist | **Frozen** — edit only with explicit user approval |
| `Plan.md` | Milestone table with **Deliverable · Acceptance · Validation · Stop-and-fix · HUMAN_GATE** columns | Codex updates Status column only |
| `Implement.md` | Ralph-loop runbook (read-state → pick-one-milestone → plan → act → validate → decide) | Frozen |
| `Documentation.md` | Append-only audit log + APPROVED token landing zone | Codex appends; user appends APPROVED tokens |

The exact templates with `{{PLACEHOLDER}}` slots live in `templates/`. The full milestone breakdown for the canonical bug-fix flow lives in `workflows/jira-bug-fix.md`.

### Phase 3 — Wire HUMAN GATEs

Codex `/goal` does **not** stop on its own for "this looks dangerous." Encode each gate in `Plan.md` as a milestone whose **only** Deliverable is "wait for `APPROVED:Gx` token in `Documentation.md`."

The canonical workflow ships with four gates:

| Gate | Guards | What the user reviews before approving |
|---|---|---|
| **G1** | `git push` to remote | `git diff ${BASE}..HEAD` and commit messages |
| **G2** | merge feature → integration branch | full PR diff (or local merge preview) and CI status |
| **G3** | trigger CI/CD deploy | integration-branch tip SHA (no surprise commits riding along) |
| **G4** | post the externally-visible ticket comment | the draft comment Codex wrote to `jira-comment.md` |

Each gate row in `Plan.md` is structured so its Validation command is `grep -F "APPROVED:Gx" Documentation.md` — the loop literally cannot pass it until the user types the token.

To **reject** a gate, the user writes `REJECTED:Gx — reason: ...` instead. Codex marks the milestone `blocked` and stops.

### Phase 4 — Hand off to Codex

Two paths. **Default to Path A** (plugin) when running inside Claude Code — it gives `/codex:status` polling and async background mode.

**Path A — `codex-plugin-cc` bridge (from Claude Code):**

```
/codex:rescue Pursue the goal at {{WORKDIR}}/.codex-goals/{{TICKET_ID}}/Prompt.md.
              Read Plan.md, Implement.md, Documentation.md as the runbook.
              Token budget: {{TOKEN_BUDGET}}. Stop on every HUMAN_GATE row.
```

Optional flags: `--background` (run async, poll with `/codex:status`), `--model <model-id>`, `--effort high` (see `codex --help` for the model IDs your install supports).

**Path B — direct `codex` (separate terminal, or Codex used standalone):**

```bash
cd "${WORKDIR}"
codex
# inside the TUI:
/goal Pursue the goal at .codex-goals/${TICKET_ID}/Prompt.md.
      Read Plan.md, Implement.md, Documentation.md as the runbook.
      Stop on every HUMAN_GATE row.
/goal budget ${TOKEN_BUDGET}
```

In both paths the **goal text is short** — substance lives in the four files. Long inline goals get truncated by mid-turn compaction (known issue #19910 in 0.128.0).

**Standalone Codex usage:** if Codex is the only agent (no Claude Code orchestrator), the user runs the auto-setup script (Phase 0) once, drafts the four files manually using `templates/`, then runs `codex` + `/goal …` as in Path B. The skill is fully self-contained — no Claude-side dependencies once the spec files exist.

### Phase 5 — Supervise & resume

While Codex runs:

- **Monitor**: `/codex:status` (Path A) or just `/goal` with no args inside the TUI (Path B).
- **Read** `Documentation.md` between gates — that is Codex's audit log. Vague language ("looks good", "should work") is a **red flag**: proxy signals are not completion evidence.
- **Resume gates** with `/goal resume` after manually verifying the diff/preview the gate is guarding.
- **If Codex marks `unmet`**: read its blocker explanation in `Documentation.md`. Either resolve and `/goal resume`, or `/goal clear` and re-spec.

**Hard rule on completion claims** (the audit step from official Codex docs — *"periodically pick a goal marked achieved and verify by hand whether it actually was"*):

1. Re-read `Prompt.md → Verification` checklist.
2. For each item, locate the corresponding evidence in `Documentation.md`.
3. Re-run **at least one** validation command yourself and paste fresh output.
4. Only then report success to the user.

## Token budget guidance

From the Codex `/goal` docs — *"iteration count is a proxy. What you actually care about is how much money the agent is allowed to spend."*

| Goal size | Token budget | Examples |
|---|---|---|
| Small | 100k–500k | Single-file fix, single endpoint |
| Medium | 500k–2M | The canonical ticket→deploy flow shipped here |
| Large | 2M–10M | Cross-service refactor, framework migration |

Set with `/goal budget <tokens>` after `/goal <objective>`. If you skip this, Codex uses an account-default budget that may be much lower than your goal needs.

## Files in this skill

- `SKILL.md` — this file (entry point; works as Codex CLI skill, Claude Code skill, or `.agents/skills/` skill)
- `templates/Prompt.md` — frozen objective spec template (Scope/Behavior/Non-goals/Verification + Done-when)
- `templates/Plan.md` — milestone table template (Deliverable/Acceptance/Validation/Stop-and-fix/Gate columns)
- `templates/Implement.md` — Ralph-loop runbook (frozen)
- `templates/Documentation.md` — empty audit-log skeleton with APPROVED-token instructions
- `workflows/jira-bug-fix.md` — full 16-milestone breakdown for the canonical ticket→deploy→report flow
- `workflows/README.md` — how to author your own workflow on top of these templates
- `install.sh` — one-shot installer (copies skill into `~/.claude/skills/`, `~/.agents/skills/`, `~/.codex/skills/`; auto-enables `goals=true`)
- `README.md` — public-facing project README

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `/goal` returns "unknown command" | `features.goals = true` missing or session not restarted | Re-run Phase 0 step 2; restart Codex |
| Goal forgets context mid-run | Mid-turn compaction lost continuation prompt (#19910) | Shrink the inline goal text — keep substance in `Prompt.md` |
| Codex skips a HUMAN_GATE | Gate row written as a normal task, not an `APPROVED:Gx` wait-state | Re-render that row from the gate template in `templates/Plan.md` |
| Codex marks complete but tests don't pass | Accepted proxy signal as completion | Re-run validation yourself; re-issue goal with stricter Verification block |
| Plugin commands not found in Claude Code | `codex-plugin-cc` not installed | `/plugin marketplace add openai/codex-plugin-cc && /plugin install codex@openai-codex` |
| `codex login status` shows API-key auth | Goals require ChatGPT auth | `codex login` → "Sign in with ChatGPT" |

## Sources (official + canonical references)

- [Run long-horizon tasks with Codex (OpenAI Developers blog)](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex)
- [Slash commands in Codex CLI (OpenAI docs)](https://developers.openai.com/codex/cli/slash-commands)
- [Best practices — Codex (OpenAI docs)](https://developers.openai.com/codex/learn/best-practices)
- [codex-plugin-cc (OpenAI's Claude Code → Codex bridge)](https://github.com/openai/codex-plugin-cc)
- [Codex /goal command deep dive (Ralphable)](https://ralphable.com/blog/codex-goal-command-ralph-loop-openai-built-in-autonomous-coding-agent-2026)
- [Simon Willison on Codex /goal](https://simonwillison.net/2026/Apr/30/codex-goals/)
