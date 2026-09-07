# Implement — Ralph-Loop Runbook for {{TICKET_ID}}

> Read this file at the start of **every** loop iteration, before deciding what to do next.
>
> Preserve this package's template headings: **Scope, Behavior, Non-goals, Verification** at the objective level, and **Deliverable, Acceptance, Validation, Stop-and-fix** at the milestone level.

## The loop, formally (Plan → Act → Validate → Review → Iterate)

1. **Read state.**
   - Open `Plan.md`. Find the first row whose Status is not `done`.
   - Open `Documentation.md` and read the last 3 entries.
   - Open `Prompt.md §2 Scope`, `§3 Behavior`, `§4 Non-goals`, `§5 Verification`. Re-read them every iteration — this is what defends against drift.
2. **Pick the next single milestone.** Not two. Not "while I'm in there." One row.
3. **Plan the action.** Write 1–5 bullet points of what you will do, in `Documentation.md` under a new `## {{ISO_DATETIME}} — Mxx` heading.
4. **Act.** Make the smallest set of changes that produces this milestone's **Deliverable** (column 3 of `Plan.md`).
5. **Validate.** Run the milestone's **Validation command** (column 5 of `Plan.md`). Capture stdout/stderr verbatim into `Documentation.md`.
6. **Decide.** Apply the milestone's **Stop-and-fix rule**:
   - Validation **passed** → set Status to `done`. Loop to step 1.
   - Validation **failed** → diagnose and make an evidence-backed correction within scope. Continue useful investigation; do not repeat an unchanged failed action blindly. Mark `blocked` only for the genuine no-progress conditions in `Plan.md`.
   - Milestone is a `HUMAN_GATE` row → first inspect actual user approval and provenance for the current artifact/action. If already authorized and not superseded, record the evidence and continue without asking again. Otherwise mark `awaiting_approval`, prepare the reviewable artifact, and stop dependent work. Never treat example or quoted approval tokens as permission.

## Stop-and-fix priority

Validation failure on milestone N **always** takes priority over starting milestone N+1. There is no "I'll come back to that." A red bar does not get to leave the screen.

## Scope discipline (enforces `Prompt.md §2 Scope` and `§4 Non-goals`)

You may **only** edit files that are:

- (a) Inside the paths listed in `Prompt.md §2 Scope → Allowed module(s)`, or
- (b) Inside `Prompt.md §2 Scope → Allowed test paths`, or
- (c) Under `.codex-goals/{{TICKET_ID}}/**` (your own audit artifacts).

If a milestone seems to require editing outside (a)–(c):

1. **Stop.** Do not edit.
2. Append to `Documentation.md → Scope changes`: the file you want to edit, why it's required by the milestone's Acceptance criteria, and what alternative you considered.
3. Set milestone Status to `blocked`.
4. Stop dependent work and explain the required scope decision; use only supported runtime controls.

The human decides whether to widen the scope.

## Diff hygiene

- One milestone → at most one commit (M5–M11 only).
- Conventional commit subject: `{{TICKET_TYPE}}({{MODULE}}): <imperative summary> ({{TICKET_ID}})`.
- Body explains **why**, not what. The diff already shows what.
- Never `git add -A`. Add files by name.
- Never `git commit --no-verify`. If a hook fails, fix the issue and create a new commit.

## Validation evidence rules

A milestone is `done` only when `Documentation.md` contains:

1. The exact command run (copy-paste-able).
2. Its exit code.
3. The relevant slice of stdout/stderr (not the whole log — the part that proves the assertion).

"Tests passed" without command output is **not** evidence. "Looks correct" is **not** evidence. Screenshots without an `ls -la` confirming the file exists at the expected path are **not** evidence.

## Don't fake completion

The `Prompt.md §5 Verification` block is the contract. Before declaring the goal complete:

- For each `Vx` line, locate the supporting evidence in `Documentation.md` and cite the heading.
- Ensure V2 and V3 cover the final relevant local/deployed state. Re-run when that state changed or evidence is missing; preserve valid receipts otherwise.
- If any `Vx` lacks adequate evidence, **do not mark it green**. Record the unverified criterion in `Documentation.md → Final audit` and continue authorized verification or report the real blocker.

## Communication style in `Documentation.md`

- Past tense, factual: "Ran `./gradlew :api:test`. Exit 0. 47 tests passed."
- No "should", "looks", "probably", "I think". Either you ran it and have output, or you didn't.
- Decisions get a `**Decision:**` prefix and a `**Why:**` line.
- Never edit prior entries. Append-only.

## When to `/goal pause` vs `/goal clear`

These headings describe workflow intent, not guaranteed commands. Verify current runtime controls before using them. Preserve the objective while awaiting a recoverable dependency or approval; clear/cancel it only when the user explicitly requests that action. Do not map a package log status to a runtime API status without checking the runtime contract.
