# Documentation — Live Audit Log for {{TICKET_ID}}

> Append-only. Codex writes here after every loop iteration. Record actual user approval provenance with APPROVED tokens; tokens alone do not grant permission.

## Goal metadata

- Ticket: `{{TICKET_ID}}` — {{TICKET_TITLE}}
- Created: `{{ISO_DATETIME}}`
- Workdir: `{{WORKDIR}}`
- Base branch: `{{BASE_BRANCH}}` → integration branch: `{{INTEGRATION_BRANCH}}`
- Token budget: `{{TOKEN_BUDGET}}`

## How the user passes a HUMAN GATE

When Codex pauses at a `HUMAN_GATE` milestone, the user reviews the relevant artifact (diff / preview / build URL / draft comment) and then appends a single line to this file in this exact format:

```
APPROVED:G1 — by {{USER_NAME}} on {{ISO_DATETIME}} — saw: {{evidence-summary, e.g. diff at commit abc1234}}
```

If the exact action is already approved, record the existing approval provenance without another approval loop. Preserve an explicit requirement for the user to enter the token personally. Use the installed runtime's supported continuation mechanism.

To **reject** a gate, write `REJECTED:Gx — reason: ...` instead. Codex will mark the milestone `blocked` and stop.

## Iteration log

<!-- Codex appends `## {{ISO_DATETIME}} — Mxx` blocks below this line. -->

## Decisions

<!-- Codex appends `**Decision:** ... **Why:** ...` blocks below this line. -->

## Blockers

<!-- Codex appends blocker entries here when a real dependency or repeated identical failure prevents useful in-scope progress. -->

## Scope changes

<!-- Codex proposes scope expansions here; the user approves before any edit outside the original scope. -->

## Final audit (Codex fills before claiming completion)

For each Verification item in `Prompt.md §5`, cite evidence for the final relevant state. Re-run only when changes, missing evidence, or unresolved concerns require it.

- V1 — `git log` shows scoped commits ending in `({{TICKET_ID}})`: _________
- V2 — regression test passes against `{{LOCAL_API}}`: _________
- V3 — regression test passes against `{{DEV_API}}`: _________
- V4 — module test suite green: _________
- V5 — both `as-is.png` and `to-be.png` exist: _________
- V6 — `report.pdf` exists with required content: _________
- V7 — all four `APPROVED:Gx` tokens present: _________
- V8 — ticket comment posted (orchestrator-side): _________

**Final status (Codex writes one of):** `complete` / `unmet — reason: ...`

These are package log values, not instructions to call a runtime status API.
