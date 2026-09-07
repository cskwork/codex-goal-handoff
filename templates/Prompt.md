# Prompt — Frozen Objective Spec for {{TICKET_ID}}

> **Frozen.** Codex must treat this file as read-only. Edits require explicit human approval recorded in `Documentation.md`.
>
> Keep **Scope, Behavior, Non-goals, Verification** as this package's stable template headings; they are not runtime parser keywords.

## 0. Single-sentence objective

Resolve {{TICKET_ID}} (`{{TICKET_TITLE}}`) end-to-end: reproduce the as-is defect, ship a targeted fix on a `{{TICKET_TYPE}}/{{TICKET_ID}}` branch off `{{BASE_BRANCH}}`, verify locally and after deploy, and produce an as-is/to-be report linked back to the ticket.

## 1. Verbatim ticket payload

> Pasted from `{{TICKET_URL}}` on `{{ISO_DATETIME}}`. Do not paraphrase below this line.

```
{{TICKET_TITLE_VERBATIM}}

{{TICKET_DESCRIPTION_VERBATIM}}

Reproduction steps:
{{TICKET_REPRO_STEPS_VERBATIM}}

Acceptance criteria from reporter:
{{TICKET_ACCEPTANCE_VERBATIM}}
```

## 2. Scope

> Exactly which files / modules / surface areas this goal is allowed to touch. Anything not listed here is out of scope by default.

- **Repo root:** `{{WORKDIR}}`
- **Allowed module(s):** `{{MODULE_PATHS}}` (e.g. `services/billing/**`, `apps/web/src/checkout/**`)
- **Allowed test paths:** `{{TEST_PATHS}}` (e.g. `services/billing/test/**`, `tests/repro/{{TICKET_ID}}.spec.ts`)
- **Allowed audit-artifact path:** `.codex-goals/{{TICKET_ID}}/**` (Codex's own scratchpad)
- **Allowed branches to create:** `{{TICKET_TYPE}}/{{TICKET_ID}}` only
- **Branch to base off:** `{{BASE_BRANCH}}` (no other base permitted)
- **Branch to merge into (gated):** `{{INTEGRATION_BRANCH}}`

If the fix logically requires editing outside this scope, Codex must **stop**, write the proposed scope expansion to `Documentation.md → Scope changes`, and wait for the user to widen the scope before continuing.

## 3. Behavior

> What must be **observably true** after the change. Behavior is what a black-box tester sees, not how the code is structured.

- **B1.** The defect described in §1 is no longer reproducible. The regression test at `{{REPRO_TEST_PATH}}` exits 0 against `{{LOCAL_API}}` and against `{{DEV_API}}`. (`{{REPRO_TEST_PATH}}` is whatever layer the test was written at — Playwright spec, integration test, unit test, etc.)
- **B2.** Every existing test in the touched modules continues to pass.
- **B3.** A new regression test exists at the lowest layer that catches the bug (unit > integration > e2e preference). It fails on the pre-fix code (proven at milestone M3) and passes on the post-fix code (proven at milestone M8).
- **B4.** No public API contract changes (no removed routes, no removed/renamed fields, no breaking response-shape changes).
- **B5.** No new external service, feature flag, or env var introduced — unless the ticket explicitly requires one and `Documentation.md → Scope changes` records the approval.
- **B6.** Branch history is reviewable: `git log {{BASE_BRANCH}}..{{TICKET_TYPE}}/{{TICKET_ID}}` shows logically scoped commits with conventional-commit subjects ending in `({{TICKET_ID}})`.

## 4. Non-goals

> Items the agent must refuse even if they are convenient or "while I'm in there" tempting.

- **N1.** Do not modify code outside §2 Scope without an approved entry in `Documentation.md → Scope changes`.
- **N2.** Do not upgrade dependencies, change build tooling, or reformat unrelated files.
- **N3.** Do not delete or rename public APIs, exported types, or ticket-numbered DB columns.
- **N4.** Do not push to `{{BASE_BRANCH}}` directly. Ever.
- **N5.** Do not `--force` push, `--no-verify`, or `git reset --hard` on a branch with unpushed user work.
- **N6.** Do not use mocks for the integration verification step (M8/M13) — must hit a real local or deployed server.
- **N7.** Do not advance past any `HUMAN_GATE` row in `Plan.md` without actual user approval covering its current artifact/action, recorded with provenance under `APPROVED:Gx` in `Documentation.md`.
- **N8.** Do not declare the goal complete on proxy signals ("tests should pass", "the fix is in place"). Verification §5 demands real command output.

## 5. Verification

> Match every criterion to evidence for the final relevant revision/environment. Re-run checks affected by changes or unresolved concerns; reuse valid evidence otherwise. Record commands, outcomes, and provenance in `Documentation.md → Final audit`. Never repeat an external mutation to refresh a verification receipt.

```
V1. git log {{BASE_BRANCH}}..{{TICKET_TYPE}}/{{TICKET_ID}} --oneline
    # Expect: ≥1 commit, each subject ends with ({{TICKET_ID}}).

V2. npx playwright test tests/repro/{{TICKET_ID}}.spec.ts
    # Expect: exit 0 against {{LOCAL_API}} after the fix.

V3. npx playwright test tests/repro/{{TICKET_ID}}.spec.ts --config=playwright.dev.config.ts
    # Expect: exit 0 against {{DEV_API}} after the deploy.

V4. {{LOCAL_TEST_CMD}}
    # Expect: exit 0; full module test suite green.

V5. test -s .codex-goals/{{TICKET_ID}}/screenshots/as-is.png \
    && test -s .codex-goals/{{TICKET_ID}}/screenshots/to-be.png
    # Expect: both screenshots exist and are non-empty, captured from the same route.

V6. test -s .codex-goals/{{TICKET_ID}}/report.pdf
    # Expect: PDF exists, embeds both screenshots, summarizes root cause + fix + verification + commit SHAs + deploy build #.

V7. Review the actual user approval and provenance for G1, G2, G3, and G4.
    # Expect: each approval covers the current artifact/action, with no superseding rejection.
    # Example or quoted APPROVED:Gx tokens are not authorization.

V8. (orchestrator-side) Ticket comment posted with merge SHA, build URL, PDF link.
    # Recorded as "APPROVED:M-COMMENT — comment ID: <id>" in Documentation.md.
```

**Done when:** every item V1–V8 has evidence for the final relevant state in `Documentation.md → Final audit`, including timestamps and any required review of artifact content.

## 6. Escalation contract

When a real dependency, missing authorization, or repeated identical failure prevents useful in-scope progress, append the milestone, attempts, evidence, and needed decision/access to `Documentation.md → Blockers`. Stop dependent work and explain the blocker. A different evidence-backed approach within scope is allowed; a fixed number of failed tests alone is not a reason to give up. Use only the installed runtime's supported goal controls.
