<div align="center">

# codex-goal-handoff

**Turn a ticket into a verified, reviewed, deployed PR — using OpenAI Codex `/goal`.**

- **What you get:** a reproduction script, a scoped fix on a branch, green local + dev verification, an as-is/to-be PDF report, and a posted ticket comment — all from one ticket ID.
- **What you do:** approve four `APPROVED:Gx` gate tokens (push, merge, deploy, public comment). Everything between gates is autonomous.
- **What it costs:** one Codex `/goal` token budget (~500k–2M tokens for a typical ticket), and the four gate reviews. No proxy-signal completions: the agent re-runs every Verification command before claiming done.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#license)
[![Codex CLI ≥ 0.128.0](https://img.shields.io/badge/Codex_CLI-%E2%89%A50.128.0-black)](https://developers.openai.com/codex/cli)
[![Works with Claude Code](https://img.shields.io/badge/Works_with-Claude_Code-D97757)](https://docs.claude.com/en/docs/claude-code)
[![Works with Codex CLI](https://img.shields.io/badge/Works_with-Codex_CLI-000)](https://developers.openai.com/codex/cli)
[![Works with .agents/skills](https://img.shields.io/badge/Works_with-.agents%2Fskills-555)](#install)

</div>

---

## Why this exists

OpenAI's Codex CLI 0.128.0 shipped [`/goal`](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex) — a persistent objective that runs the **Ralph Loop** (Plan → Act → Test → Review → Iterate) until done, paused, or out of budget. It's a real long-horizon agent.

But raw `/goal` has three problems for production work:

1. **It does not stop on its own** for irreversible actions (push, merge, deploy, externally-visible comments).
2. **It happily accepts proxy signals** as completion — "tests should pass," "the fix is in place" — without running them.
3. **A short inline goal text gets truncated by mid-turn compaction** ([codex#19910](https://github.com/openai/codex/issues/19910)), so substance has to live in files Codex re-reads every iteration.

`codex-goal-handoff` is a **portable skill** that fixes all three:

- It generates the **four-file durable spec** (`Prompt.md`, `Plan.md`, `Implement.md`, `Documentation.md`) that Codex's docs recommend.
- It uses the **official Codex objective vocabulary verbatim** — `Scope · Behavior · Non-goals · Verification` at the objective level, `Deliverable · Acceptance · Validation · Stop-and-fix` per milestone.
- It encodes **HUMAN GATEs** as wait-state milestones whose validation is a literal `grep "APPROVED:Gx"` — the loop **cannot** advance without you.
- It works in **three host environments**: OpenAI Codex CLI standalone, Claude Code, and any agent runtime that reads `~/.agents/skills/`.

## 30-second demo

```text
You (in Claude Code):  use codex-goal-handoff to fix PROJ-1234

Skill:  • verifies Codex >= 0.128.0, ChatGPT auth, features.goals=true
        • fetches the ticket, pastes verbatim text into Prompt.md
        • renders Plan.md (16 milestones, 4 gates), Implement.md, Documentation.md
        • hands off:  /codex:rescue Pursue the goal at .codex-goals/PROJ-1234/Prompt.md

Codex:  M1 done · M2 done · M3 reproduces (intentionally fails) · M4 explores ·
        M5 branch · M6 fix · M7 unit pass · M8 playwright pass · M9 curl pass
        [paused] G1 — awaiting APPROVED:G1 (push approval)

You:    [reads diff] APPROVED:G1 — by alice — saw: commit 7f3a1c2

Codex:  M10 push · [paused] G2 ...

[ ... three gates later ... ]

Codex:  Final audit
        ok V1 git log — 1 commit (PROJ-1234)
        ok V2 playwright local — exit 0
        ok V3 playwright dev   — exit 0
        ok V4 module tests     — exit 0
        ok V5 screenshots      — both present
        ok V6 report.pdf       — generated
        ok V7 four gate tokens — all approved
        ok V8 ticket comment   — posted (id 8821)
        Status: complete
```

## Install

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/cskwork/codex-goal-handoff/main/install.sh | bash
```

The installer:

- **Detects** which agent-skill parents exist on your machine (`~/.claude/`, `~/.agents/`, `~/.codex/`) and copies the skill into each one's `skills/` subdirectory.
- **Backs up** any existing copy to `<dir>.bak-<timestamp>` before overwriting.
- **Auto-enables** `features.goals = true` in `~/.codex/config.toml` (idempotent; backs up the config first).
- **Skips** parents that don't exist — no pollution.

Pass `--dry-run` to preview, or `--uninstall` to remove all installed copies.

### Paste-into-the-LLM install

Don't want to run a script? Paste this into Claude Code or Codex:

```
Install the codex-goal-handoff skill from
https://github.com/cskwork/codex-goal-handoff

Steps:
  1. git clone https://github.com/cskwork/codex-goal-handoff /tmp/cgh
  2. bash /tmp/cgh/install.sh
  3. Confirm `codex login status` shows ChatGPT auth.
  4. (Claude Code only, optional)
       /plugin marketplace add openai/codex-plugin-cc
       /plugin install codex@openai-codex
  5. Verify with `codex` then `/goal` — should be a known command.
```

### Manual

```bash
git clone https://github.com/cskwork/codex-goal-handoff
cp -r codex-goal-handoff ~/.claude/skills/      # or ~/.agents/skills/, ~/.codex/skills/
# enable the feature flag manually:
printf '\n[features]\ngoals = true\n' >> ~/.codex/config.toml   # only if [features] section absent
codex login   # choose "Sign in with ChatGPT"
```

## How it works

### The four files

Every long-horizon goal lives in `${WORKDIR}/.codex-goals/<TICKET_ID>/`:

```
.codex-goals/PROJ-1234/
├── Prompt.md          frozen objective spec — Scope, Behavior, Non-goals, Verification
├── Plan.md            milestone table       — Deliverable, Acceptance, Validation, Stop-and-fix, HUMAN_GATE
├── Implement.md       Ralph-loop runbook    — read-state -> pick-one -> plan -> act -> validate -> decide
├── Documentation.md   live audit log        — Codex appends; you append APPROVED tokens here
├── exploration.md     Codex's repo notes (file:line citations)
├── screenshots/
│   ├── as-is.png
│   └── to-be.png
├── curl/run.sh        API smoke harness
├── jira-comment.md    draft external comment
└── report.pdf         final as-is/to-be report
```

### The vocabulary (official Codex `/goal` terms — used verbatim)

**Objective level** (in `Prompt.md`):

| Term | What it controls |
|---|---|
| **Scope** | Exactly which files / modules / surfaces are allowed to change. |
| **Behavior** | What must be **observably** true after the change (black-box, not implementation). |
| **Non-goals** | Things the agent must refuse even when convenient. |
| **Verification** | Concrete shell commands whose green output proves the objective achieved. |

**Milestone level** (every row in `Plan.md`):

| Term | What it controls |
|---|---|
| **Deliverable** | The artifact this milestone produces (file, commit, screenshot, build). |
| **Acceptance criteria** | The observable property the deliverable must have. |
| **Validation command** | A copy-pasteable `exit-0` shell command proving acceptance. |
| **Stop-and-fix rule** | What to do on failure: fix root cause; never retry the same milestone more than once. |

These are **not synonyms we picked.** They are the exact words OpenAI's `/goal` documentation uses, and Codex's internal prompts key off them. Renaming to "Goals" or "Acceptance Tests" loses alignment with Codex's continuation prompts.

### The Ralph loop, formally

```
+------------------------------------------------------------------+
|                                                                  |
|   1. Read state          (Plan.md -> first non-done row,         |
|                           Documentation.md -> last 3 entries,    |
|                           Prompt.md sections 2-5)                |
|   2. Pick ONE milestone                                          |
|   3. Plan the action     (write 1-5 bullets to Documentation.md) |
|   4. Act                 (smallest change producing Deliverable) |
|   5. Validate            (run Validation command; capture output)|
|   6. Decide:                                                     |
|        green -> Status=done -> loop                              |
|        first  fail -> diagnose, edit once, re-validate           |
|        second fail -> Status=blocked, /goal pause                |
|        gate        -> Status=awaiting_approval, /goal pause      |
|                                                                  |
+------------------------------------------------------------------+
```

### The four HUMAN GATEs

The canonical workflow ships with four wait-states. Each one's Validation is a literal `grep "APPROVED:Gx" Documentation.md` — Codex cannot advance until you write the token.

| Gate | Guards | What you review |
|---|---|---|
| **G1** | `git push` to remote | `git diff base..HEAD`, commit messages |
| **G2** | merge feature into integration branch | full PR diff, CI status, teammate comments |
| **G3** | trigger CI/CD deploy | integration-branch tip SHA — make sure no surprise commit is riding along |
| **G4** | post the externally-visible ticket comment | the draft comment Codex wrote to `jira-comment.md` |

You write `APPROVED:G2 — by alice — saw: PR #321 green` to `Documentation.md` and `/goal resume`. Or `REJECTED:G2 — reason: ...` and the milestone goes `blocked`.

## Customizing for your repo

The shipped workflow (`workflows/jira-bug-fix.md`) targets the most common case: a ticketed bug, Playwright reproduction, branch/fix/merge, CI-system deploy, browser re-verify, PDF, comment.

To adapt:

1. **Point at your ticket system.** Set `{{TICKET_PROVIDER}}` to `jira` / `linear` / `github` / `asana`. The skill picks the right MCP / CLI for M1 (fetch) and M15 (comment).
2. **Point at your CI.** Fill `{{CI_DEPLOY_TRIGGER}}` and `{{CI_DEPLOY_POLL}}` with the right Jenkins / GitHub Actions / GitLab / CircleCI commands. `workflows/jira-bug-fix.md` has copy-pasteable snippets for the common four.
3. **Point at your test runner.** Fill `{{LOCAL_TEST_CMD}}` and `{{LOCAL_START_CMD}}`. Examples for Spring Boot / pnpm / npm / pytest / Go / Cargo are in `workflows/jira-bug-fix.md`.
4. **Adjust scope.** Edit `Prompt.md §2 Scope -> Allowed module(s)` to point at your service tree.

For workflows other than bug-fix, see `workflows/README.md` — the rules for authoring your own workflow on top of the same four-file model.

## How this differs from raw `/goal`

| | Raw `/goal` | `codex-goal-handoff` |
|---|---|---|
| Objective vocabulary | Free-form prose | **Scope / Behavior / Non-goals / Verification** template |
| Milestone structure | Implicit | Explicit table with **Deliverable / Acceptance / Validation / Stop-and-fix** columns |
| Compaction safety | Inline goal can be truncated | Substance lives in files re-read every iteration |
| Stops on irreversible actions | No | Yes — explicit `APPROVED:Gx`-token gates |
| Stops on proxy signals | No | Yes — Final audit must re-run every Verification command |
| Cross-host portability | Codex CLI only | Codex CLI + Claude Code + `.agents/skills/` |
| Ticket-system handoff | Manual | M1 / M15 / G4 wired |
| CI/CD deploy gating | Manual | G3 + M12 wired (Jenkins / GH Actions / GitLab examples) |

## FAQ

**Does this require a ChatGPT subscription?**
Yes — `/goal`'s persistence layer is tied to ChatGPT account auth. API-key auth does not enable goals. (`codex login status` should print "ChatGPT".)

**Does it work without Claude Code?**
Yes. Run `install.sh` (or the manual steps), then use `codex` directly: `codex` then `/goal pursue the goal at .codex-goals/<id>/Prompt.md`. The skill files are pure markdown — no host-specific runtime.

**Why four files instead of one big prompt?**
Because Codex 0.128.0 has a known mid-turn compaction bug ([codex#19910](https://github.com/openai/codex/issues/19910)) where a long inline goal can lose its continuation prompt. Putting substance in files Codex re-reads on each iteration is the documented mitigation.

**What if my repo's branch convention isn't `main`/`develop`?**
Set `{{BASE_BRANCH}}` and `{{INTEGRATION_BRANCH}}` to whatever your team uses. The skill's templates are 100% placeholders — there are no hard-coded names.

**Can I add a fifth gate?**
Yes. Add a `**Gx**` row to `Plan.md` whose Deliverable is `(gate) ...` and whose Validation is `grep -F "APPROVED:Gx" Documentation.md`. Done.

**Does it work for features, not just bugs?**
Yes — set `TICKET_TYPE=feat` and adjust `workflows/jira-bug-fix.md` (or write a new workflow file). The four-file model is workflow-agnostic.

**Why not just use `/work` + `/verify` skills?**
Those are great for short-horizon work in a single Claude Code session. `/goal` is for tasks that outlive a session and need persistence + budget control + automatic resumption after compaction. Different tool for a different job — they compose well.

## Compatibility

- **Codex CLI:** ≥ 0.128.0 (first `/goal` release)
- **ChatGPT auth required** (not API-key auth)
- **Skill hosts:** Claude Code (`~/.claude/skills/`), `.agents/skills/`-compatible runtimes, Codex CLI (`~/.codex/skills/`)
- **OS:** macOS, Linux, WSL. Windows native: install.sh runs under Git Bash.

## Contributing

PRs welcome. Areas where help is most appreciated:

- More CI-system snippets for `workflows/jira-bug-fix.md` (Buildkite, TeamCity, Bitbucket Pipelines)
- More `{{LOCAL_TEST_CMD}}` examples for less-common stacks
- New workflow files (`workflows/feat-implementation.md`, `workflows/dependency-upgrade.md`, `workflows/migration.md`)
- Translations of `SKILL.md` and `README.md`

When proposing a workflow, follow `workflows/README.md` — the rules for keeping the official vocabulary intact.

## License

MIT. See `LICENSE`.

## Acknowledgements

- OpenAI for shipping [`/goal`](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex) and the [codex-plugin-cc bridge](https://github.com/openai/codex-plugin-cc).
- Anthropic for [Claude Code](https://docs.claude.com/en/docs/claude-code) and its skill system.
- Everyone who wrote about the Ralph Loop pattern early — particularly [Simon Willison's writeup](https://simonwillison.net/2026/Apr/30/codex-goals/).
