# Workflow — Ticket Bug-Fix (canonical 16-milestone flow)

This is the workflow `templates/Plan.md` is parameterized for. Use it as the reference when filling placeholders. The flow is provider-agnostic — it works for Jira, Linear, GitHub Issues, Asana, or any other ticket system that exposes a fetch-and-comment API.

## Conceptual phases

```
┌── Reproduce ───┐  ┌── Fix ──────┐  ┌── Verify ────┐  ┌── Ship ──────┐  ┌── Report ────┐
│ M1 fetch       │  │ M5 branch   │  │ M8 playwright│  │ G2 approve   │  │ M14 PDF      │
│ M2 as-is shot  │  │ M6 implement│  │ M9 curl smoke│  │ M11 merge    │  │ G4 approve   │
│ M3 playwright  │  │ M7 unit/int │  │              │  │ G3 approve   │  │ M15 comment  │
│ M4 explore     │  │             │  │              │  │ M12 deploy   │  │ M16 audit    │
│                │  │ G1 approve  │  │              │  │ M13 dev verify  │              │
│                │  │ M10 push    │  │              │  │              │  │              │
└────────────────┘  └─────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

## Why this shape

- **Reproduce before fix.** A Playwright script that *fails* on the buggy code is the only thing that proves "fixed" later. Without M3, "verified" is just "didn't crash."
- **Local verify before push.** M7–M9 catch ~90% of regressions cheaply. Pushing first wastes a CI build slot and costs other engineers' attention.
- **Two gates before ship.** G1 (push) is light; G2 (merge to integration branch) is the real review gate. Splitting them lets reviewers spot-check the diff before it touches the integration line.
- **Re-verify on dev.** M13 re-runs the same Playwright script against the deployed URL. Same script, two environments → identical assertion → no "works on my machine."
- **PDF before ticket comment.** G4 is the last gate because the ticket comment is externally visible. Generating the PDF first means G4's reviewer sees the artifact they'll be linking to.

## Per-milestone notes (mapped to official `Deliverable / Acceptance / Validation / Stop-and-fix`)

### M1 — Fetch ticket

**Orchestrator-side, before handoff.** The `/goal` runtime does not have ticket-system credentials. Use a ticket-provider MCP (e.g. `mcp__claude_ai_Atlassian__getJiraIssue`, Linear MCP, `gh issue view`) to pull title, description, repro steps, and acceptance criteria, then paste **verbatim** into `Prompt.md §1`.

**Stop-and-fix:** if no MCP and no API access exists, ask the user to paste the ticket body directly. Never paraphrase — paraphrased tickets cause off-target fixes.

### M2 — As-is screenshot

Use Playwright **headed** mode for the first capture so the user can sanity-check the agent went to the right URL with the right account.

```bash
mkdir -p .codex-goals/{{TICKET_ID}}/screenshots
npx playwright codegen --target=javascript \
  --output=tests/repro/{{TICKET_ID}}.spec.ts \
  {{REPRO_URL}}
# Inside the recorder: reproduce the bug, then add:
#   await page.screenshot({ path: '.codex-goals/{{TICKET_ID}}/screenshots/as-is.png' });
```

**Acceptance:** the file exists, is non-empty, and visibly shows the defect described in the ticket.

### M3 — Playwright reproduction must FAIL on current code

The Validation command intentionally checks `$? -ne 0`. If the script passes on buggy code, the script does not exercise the bug — Codex must rewrite it before advancing.

**Stop-and-fix:** if the script keeps passing, the assertion is wrong. Walk the ticket's repro steps line-by-line; the wrong assertion is almost always at the last step.

### M4 — Explore

Codex writes citations to `.codex-goals/{{TICKET_ID}}/exploration.md`. Format:

```
src/path/to/file.ts:123 — handles the X case (one-sentence description)
src/path/to/other.ts:45-67 — defines the Y validator (one-sentence description)
Hypothesis: root cause is at file.ts:123 because <reasoning>.
```

This becomes the basis for **AD1** (fix layer) in `Plan.md`.

### M5 — Branch

`git fetch origin && git checkout -b {{TICKET_TYPE}}/{{TICKET_ID}} origin/{{BASE_BRANCH}}` ensures branching from the **remote** tip, not a stale local ref. `git switch -c` is fine if available.

### M6 — Implement

Codex respects scope-discipline rules in `Implement.md`. If the fix needs a new utility, that utility lives in the same module unless an existing util elsewhere obviously fits (Reuse over duplicate).

**One milestone → at most one commit per logical concern.** Conventional-commit subject: `{{TICKET_TYPE}}({{MODULE}}): <imperative summary> ({{TICKET_ID}})`. Body explains **why**, not what.

### M7 — Unit / integration

`{{LOCAL_TEST_CMD}}` is project-specific. Common forms:

| Stack | Example |
|---|---|
| Spring Boot | `./gradlew :module-name:test --tests "*{{TICKET_ID}}*"` |
| Node / pnpm | `pnpm --filter <pkg> test` |
| Node / npm | `npm test -- --testPathPattern={{module}}` |
| Python / pytest | `pytest tests/{{module}}/ -k "{{ticket_lower}}"` |
| Go | `go test ./{{module}}/... -run "{{TestName}}"` |
| Rust | `cargo test --package {{module}} {{test_filter}}` |

Fill the placeholder when rendering `Plan.md`.

### M8 — Local Playwright re-run

The same script from M3 must now pass. If it doesn't, the fix is wrong — go back to M6, do not patch the test (Stop-and-fix: never edit tests to make red turn green).

### M9 — curl smoke

Build a small `.codex-goals/{{TICKET_ID}}/curl/run.sh` hitting touched endpoints with happy-path, boundary, and one negative payload. Pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail
BASE="{{LOCAL_API}}"
# Happy
curl -fsS "$BASE/resource/123" | jq -e '.status == "ok"'
# Boundary
curl -fsS "$BASE/resource?limit=0" | jq -e '.items | length == 0'
# Negative
curl -fsS -o /dev/null -w "%{http_code}" "$BASE/resource/does-not-exist" | grep -Fx 404
```

### G1 — Push approval

User reviews `git diff {{BASE_BRANCH}}..HEAD` and `git log --oneline {{BASE_BRANCH}}..HEAD`. After eyeballing, append to `Documentation.md`:

```
APPROVED:G1 — by <user> on <ISO datetime> — saw: diff at <commit-sha>
```

### M10 — Push

`git push -u origin {{TICKET_TYPE}}/{{TICKET_ID}}`.

**Stop-and-fix:** if the branch already exists on remote with conflicting commits, do **not** `--force-with-lease` without a fresh G1 approval naming the force-push specifically.

### G2 — Merge approval

The serious gate. User checks: PR diff, CI status if applicable, any teammate comments. Append `APPROVED:G2 — by <user> — saw: PR #N green, reviewers: <names>`.

### M11 — Merge

`--no-ff` is required so the merge commit carries the ticket ID and is revertable as a unit. `git push` after merge.

### G3 — Deploy approval

User confirms the integration-branch tip is what they want deployed. Often there are multiple in-flight features — check no other teammate's commit is accidentally riding along. Append `APPROVED:G3 — by <user> — saw: {{INTEGRATION_BRANCH}} @ <sha>`.

### M12 — CI/CD trigger + poll

`{{CI_DEPLOY_TRIGGER}}` and `{{CI_DEPLOY_POLL}}` are CI-system-specific. Examples:

**Jenkins:**

```bash
TRIGGER:  curl -X POST -u "$CI_USER:$CI_TOKEN" \
            "$CI_URL/job/$JOB/buildWithParameters?BRANCH={{INTEGRATION_BRANCH}}"
POLL:     until [ "$(curl -fsS -u "$CI_USER:$CI_TOKEN" \
            "$CI_URL/job/$JOB/lastBuild/api/json" | jq -r .result)" = "SUCCESS" ]; \
            do sleep 30; done
```

**GitHub Actions:**

```bash
TRIGGER:  gh workflow run deploy.yml --ref {{INTEGRATION_BRANCH}}
POLL:     gh run watch $(gh run list --workflow=deploy.yml --limit 1 --json databaseId -q '.[0].databaseId')
```

**GitLab CI:**

```bash
TRIGGER:  curl -X POST -F "token=$TRIGGER_TOKEN" -F "ref={{INTEGRATION_BRANCH}}" \
            "$GITLAB/api/v4/projects/$PROJECT_ID/trigger/pipeline"
POLL:     until [ "$(curl -fsS -H "PRIVATE-TOKEN: $TOKEN" \
            "$GITLAB/api/v4/projects/$PROJECT_ID/pipelines?ref={{INTEGRATION_BRANCH}}&per_page=1" \
            | jq -r '.[0].status')" = "success" ]; do sleep 30; done
```

**Stop-and-fix on `FAILURE` / `UNSTABLE`:** mark `blocked`, paste the build URL into `Documentation.md → Blockers`, do not auto-retry.

### M13 — Dev re-verify

Same Playwright script, different config (`playwright.dev.config.ts` points at `{{DEV_API}}`). Capture `screenshots/to-be.png` after the assertion passes.

### M14 — PDF report

Smallest dependency: `npx mdpdf` after rendering a small `report.md` template:

```bash
cat > .codex-goals/{{TICKET_ID}}/report.md <<'EOF'
# {{TICKET_ID}} — {{TICKET_TITLE}}

## Root cause
{{ROOT_CAUSE_3_SENTENCES}}

## Fix
{{FIX_SUMMARY_5_SENTENCES}}

## Verification
- Local: `<command>` exit 0
- Dev:   `<command>` exit 0
- Commit: `{{MERGE_SHA}}`
- Build:  `{{CI_BUILD_URL}}`

## As-is
![](screenshots/as-is.png)

## To-be
![](screenshots/to-be.png)
EOF

npx mdpdf .codex-goals/{{TICKET_ID}}/report.md \
          .codex-goals/{{TICKET_ID}}/report.pdf
```

Fallback if `mdpdf` is unavailable: `chromium --headless --print-to-pdf=report.pdf file://...html` after a tiny markdown→html step (e.g. `npx marked-cli`).

### G4 — Comment approval

User reads the **draft comment** Codex wrote to `.codex-goals/{{TICKET_ID}}/jira-comment.md` (the filename stays `jira-comment.md` for backward compatibility, but content is provider-agnostic). Approve only after reading. Append `APPROVED:G4 — by <user> — saw: draft comment`.

### M15 — Ticket comment

Posted **orchestrator-side** (Codex inside `/goal` does not have authenticated ticket access).

Pattern: Codex marks M15 `awaiting_orchestrator`, the orchestrator (Claude Code or human) reads `jira-comment.md`, posts via the appropriate API:

| Provider | API |
|---|---|
| Jira | `mcp__claude_ai_Atlassian__addCommentToJiraIssue` |
| Linear | Linear MCP `createComment` |
| GitHub Issues | `gh issue comment {{TICKET_ID}} --body-file jira-comment.md` |
| Asana | Asana API `tasks/{gid}/stories` |

Then write `APPROVED:M-COMMENT — comment ID <id>` to `Documentation.md`. Codex resumes and marks M15 `done`.

### M16 — Final audit

Codex walks `Prompt.md §5 Verification` checklist (V1–V8). Each item must cite the `Documentation.md` heading containing **fresh** command output (re-run in this final iteration; stale output from 10 iterations ago does not count).

If any V-line cannot be cited from real fresh output, do **not** check it — mark the goal `unmet` and explain in `Documentation.md → Final audit`.

## Project-specific placeholders to fill before handoff

| Placeholder | Where | Example |
|---|---|---|
| `{{LOCAL_TEST_CMD}}` | M7 | `./gradlew :api:test`, `pnpm test` |
| `{{LOCAL_START_CMD}}` | M8 | `./gradlew bootRun &`, `pnpm dev &` |
| `{{BOOT_WAIT_SEC}}` | M8 | `15` (server warmup) |
| `{{CI_DEPLOY_TRIGGER}}` | M12 | see CI examples above |
| `{{CI_DEPLOY_POLL}}` | M12 | see CI examples above |
| `{{MODULE}}` | commit subject | `billing-api` |
| `{{TICKET_PROVIDER}}` | M1, M15 | `jira`, `linear`, `github`, `asana` |
| `{{ROOT_CAUSE_3_SENTENCES}}` | report | filled at M14 |
| `{{FIX_SUMMARY_5_SENTENCES}}` | report | filled at M14 |
| `{{MERGE_SHA}}` | report | filled at M11 |
| `{{CI_BUILD_URL}}` | report | filled at M12 |

If any placeholder is unknown at handoff time, ask the user once — do not guess. A wrong CI job name silently deploys the wrong service.
