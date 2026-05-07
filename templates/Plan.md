# Plan — Milestone Sequence for {{TICKET_ID}}

> Every row uses the official Codex milestone-checkpoint vocabulary: **Deliverable · Acceptance · Validation · Stop-and-fix · HUMAN_GATE.**
>
> Codex updates only the **Status** column. Do not reorder rows. Do not skip past a `HUMAN_GATE` row without the matching `APPROVED:Gx` token in `Documentation.md`.

## Status legend

- `pending` — not started
- `in_progress` — currently working
- `done` — Validation command passed and fresh output recorded in `Documentation.md`
- `blocked` — see `Documentation.md → Blockers`
- `awaiting_approval` — HUMAN_GATE; waiting on user to write `APPROVED:Gx` token

## Stop-and-fix rule (applies to every row unless a row overrides it)

When Validation fails on milestone **N**:

1. **First failure** → diagnose root cause, make a corrective edit, re-validate. If green, mark `done`. Do not advance to N+1 until N is green.
2. **Second consecutive failure on the same milestone** → set Status to `blocked`, append to `Documentation.md → Blockers`, call `/goal pause`. Do **not** retry a third time. Do **not** "try a different approach" without first surfacing the blocker.
3. Validation failure on N **always** takes priority over starting N+1. There is no "I'll come back to that."

## Milestones

| # | ID | Deliverable | Acceptance criteria | Validation command (must exit 0; capture output to `Documentation.md`) | HUMAN_GATE | Status |
|---|---|---|---|---|---|---|
| 1 | M1 | `Prompt.md §1` filled with verbatim ticket text | The pasted title/desc/repro/acceptance match the live ticket exactly | `grep -F "{{TICKET_TITLE_VERBATIM}}" .codex-goals/{{TICKET_ID}}/Prompt.md` | — | pending |
| 2 | M2 | `screenshots/as-is.png` captured at `{{REPRO_URL}}` showing the defect | File exists, non-empty, taken from the URL named in the ticket | `test -s .codex-goals/{{TICKET_ID}}/screenshots/as-is.png` | — | pending |
| 3 | M3 | `tests/repro/{{TICKET_ID}}.spec.ts` Playwright script that reproduces the bug | Script exists; runs against `{{LOCAL_API}}`; **fails** (exits non-zero) on the current pre-fix code | `npx playwright test tests/repro/{{TICKET_ID}}.spec.ts; test $? -ne 0` | — | pending |
| 4 | M4 | `.codex-goals/{{TICKET_ID}}/exploration.md` with `file:line` citations of the suspect surface | Each suspect line is annotated with one-sentence "what this does"; root cause hypothesis stated | `test -s .codex-goals/{{TICKET_ID}}/exploration.md` | — | pending |
| 5 | M5 | New branch `{{TICKET_TYPE}}/{{TICKET_ID}}` based on `origin/{{BASE_BRANCH}}` | HEAD is on the new branch, branched from the **remote** tip (not stale local) | `git fetch origin && git rev-parse --abbrev-ref HEAD \| grep -Fx "{{TICKET_TYPE}}/{{TICKET_ID}}"` | — | pending |
| 6 | M6 | One or more commits implementing the minimal fix per `Prompt.md §3 Behavior` | Diff stays inside `Prompt.md §2 Scope`; conventional-commit subjects end with `({{TICKET_ID}})` | `git log {{BASE_BRANCH}}..HEAD --oneline \| grep -F "({{TICKET_ID}})"` and `git diff {{BASE_BRANCH}}..HEAD --stat` (must be non-empty) | — | pending |
| 7 | M7 | All module unit/integration tests green | Full suite for touched modules exits 0; no test was deleted or skipped to make it green | `{{LOCAL_TEST_CMD}}` | — | pending |
| 8 | M8 | Local Playwright run of M3's script now **passes** | Same script that failed at M3 now exits 0 — fix verified end-to-end against `{{LOCAL_API}}` | `{{LOCAL_START_CMD}} & sleep {{BOOT_WAIT_SEC}}; npx playwright test tests/repro/{{TICKET_ID}}.spec.ts` | — | pending |
| 9 | M9 | `.codex-goals/{{TICKET_ID}}/curl/run.sh` happy-path + boundary + negative API smoke | All curl assertions exit 0 against `{{LOCAL_API}}` | `bash .codex-goals/{{TICKET_ID}}/curl/run.sh` | — | pending |
| 10 | **G1** | (gate) User has reviewed the diff and approved push | `Documentation.md` contains `APPROVED:G1` token | `grep -F "APPROVED:G1" .codex-goals/{{TICKET_ID}}/Documentation.md` | **YES** | pending |
| 11 | M10 | Branch pushed to remote | `git ls-remote --heads origin` shows `{{TICKET_TYPE}}/{{TICKET_ID}}` at HEAD's SHA | `git push -u origin {{TICKET_TYPE}}/{{TICKET_ID}} && git ls-remote --heads origin {{TICKET_TYPE}}/{{TICKET_ID}} \| grep -q .` | — | pending |
| 12 | **G2** | (gate) User has reviewed the PR and approved merge to `{{INTEGRATION_BRANCH}}` | `Documentation.md` contains `APPROVED:G2` token | `grep -F "APPROVED:G2" .codex-goals/{{TICKET_ID}}/Documentation.md` | **YES** | pending |
| 13 | M11 | `{{INTEGRATION_BRANCH}}` tip contains the merge commit referencing `{{TICKET_ID}}` | `git log -1 --pretty=%s` on `{{INTEGRATION_BRANCH}}` mentions the ticket; merge is `--no-ff` (revertable as a unit) | `git checkout {{INTEGRATION_BRANCH}} && git pull && git merge --no-ff {{TICKET_TYPE}}/{{TICKET_ID}} && git push && git log -1 --pretty=%s \| grep -F "{{TICKET_ID}}"` | — | pending |
| 14 | **G3** | (gate) User confirmed integration-branch tip is what they want deployed | `Documentation.md` contains `APPROVED:G3` token | `grep -F "APPROVED:G3" .codex-goals/{{TICKET_ID}}/Documentation.md` | **YES** | pending |
| 15 | M12 | CI/CD deploy of `{{INTEGRATION_BRANCH}}` to dev finished SUCCESS | The CI system reports the run terminated with success state | `{{CI_DEPLOY_TRIGGER}} && {{CI_DEPLOY_POLL}}` | — | pending |
| 16 | M13 | `screenshots/to-be.png` captured + Playwright passes against `{{DEV_API}}` | `to-be.png` exists from the same route as `as-is.png`; same Playwright script exits 0 against deployed URL | `test -s .codex-goals/{{TICKET_ID}}/screenshots/to-be.png && npx playwright test tests/repro/{{TICKET_ID}}.spec.ts --config=playwright.dev.config.ts` | — | pending |
| 17 | M14 | `report.pdf` generated with as-is/to-be comparison + root-cause + fix + verification | PDF exists, embeds both screenshots, lists commit SHA(s) and deploy build # | `test -s .codex-goals/{{TICKET_ID}}/report.pdf` | — | pending |
| 18 | **G4** | (gate) User reviewed the draft ticket comment and approved posting | `Documentation.md` contains `APPROVED:G4` token | `grep -F "APPROVED:G4" .codex-goals/{{TICKET_ID}}/Documentation.md` | **YES** | pending |
| 19 | M15 | Ticket comment posted (orchestrator-side) with merge SHA, build URL, PDF link | `Documentation.md` records the comment ID returned by the ticket system | `grep -F "APPROVED:M-COMMENT" .codex-goals/{{TICKET_ID}}/Documentation.md` | — | pending |
| 20 | M16 | Final audit: every Verification command in `Prompt.md §5` re-run in this iteration, fresh output recorded | `Documentation.md → Final audit` cites a fresh-output entry for V1..V8; all green | (manual: orchestrator re-runs at least one Verification command and confirms exit 0) | — | pending |

## Architectural decisions (Codex fills as it makes them)

- **AD1.** Fix layer: _________ (controller / service / mapper / config / view / other) — **Why:** _________
- **AD2.** Regression-test layer: _________ (unit / integration / playwright) — **Why:** _________
- **AD3.** _________

## Oscillation prevention

If a milestone fails the same way twice in a row, **do not retry a third time** (Stop-and-fix rule). Record the failure under `Documentation.md → Blockers` and `/goal pause`. The agent's job is not to make red turn green by repetition.
