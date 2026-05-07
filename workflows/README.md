# Authoring a workflow

A "workflow" in this skill is a markdown file under `workflows/` that maps a real-world long-horizon task onto the four-file durable-spec model. The shipped one (`jira-bug-fix.md`) covers ticketed bug fixes; this guide explains how to write your own.

## The contract

A workflow file is a contract between three readers:

1. **The orchestrator** (Claude Code or you) — reads it to fill `templates/Prompt.md` and `templates/Plan.md`.
2. **Codex `/goal`** — never reads the workflow file directly; reads the rendered `Plan.md` / `Prompt.md` it produces.
3. **The user** — reads it to understand what they're approving at each gate.

If any of those three can't get what they need from the workflow file, it isn't done.

## Mandatory structure

Every workflow file MUST contain these sections:

```markdown
# Workflow — <Name>

## Conceptual phases       <!-- ASCII diagram of the milestone groupings -->

## Why this shape          <!-- 3-6 bullets defending the ordering -->

## Per-milestone notes     <!-- M1, M2, ..., Gx — one heading per milestone -->

## Project-specific placeholders to fill before handoff
                            <!-- table mapping {{PLACEHOLDER}} -> where -> example -->
```

## Vocabulary rules — do not paraphrase

This skill keeps tight alignment with the official OpenAI Codex `/goal` documentation. When writing a workflow file:

- **Objective-level sections** in `Prompt.md` are always: `Scope`, `Behavior`, `Non-goals`, `Verification`. Don't rename to "Goals," "Acceptance," "Constraints," "Done When." Codex's continuation prompts key off these exact words.
- **Milestone-level columns** in `Plan.md` are always: `Deliverable`, `Acceptance criteria`, `Validation command`, `Stop-and-fix`, `HUMAN_GATE`. Don't merge "Acceptance" into "Validation" — they are different things (one is the property to verify; the other is the command that verifies it).
- **Gate tokens** are always `APPROVED:Gx` / `REJECTED:Gx` (capital A, capital REJECTED, capital G, integer). Don't lowercase. Codex grep is case-sensitive and the templates rely on exact match.

## Milestone authoring rules

Each milestone row in `Plan.md` must satisfy all five:

1. **One Deliverable.** A milestone produces one artifact. If you're writing two, split into two milestones.
2. **Observable Acceptance.** The Acceptance must be checkable from outside the agent (file exists, exit code, response body, screenshot present). Internal state ("Codex understands the issue") is not acceptable.
3. **Mechanical Validation.** The Validation command must be a real shell command with a real `exit 0` semantic. No "the agent is satisfied" or "tests look good." If you can't write the command, the milestone is not ready.
4. **Stop-and-fix is uniform.** Apply the same rule from `templates/Plan.md`: first failure -> root-cause-fix once; second consecutive failure -> `blocked` + `/goal pause`. Don't write a milestone that needs three retries.
5. **Gates are wait-states.** A `HUMAN_GATE` row's Deliverable is *only* "user has approved Gx." Its Validation is *only* `grep -F "APPROVED:Gx" Documentation.md`. Don't pile other work into a gate row.

## Number-of-gates heuristic

How many gates is right for your workflow?

- **0 gates.** Only for workflows with no irreversible actions (e.g. "generate a docs site preview locally").
- **1 gate.** For workflows that culminate in a single irreversible action (e.g. "publish to npm" -> one gate before publish).
- **2-4 gates.** Typical for ticket-driven flows with push, merge, deploy, externally-visible comment.
- **5+ gates.** Probably split into two workflows. The user gets gate-fatigue and starts approving without reading.

## Templates a workflow file must point at

The workflow file does not duplicate template content. It explains *how to fill* the templates for this workflow. So a typical per-milestone note looks like:

```markdown
### M7 — Unit / integration

**Deliverable:** module test suite green.
**Acceptance:** all touched modules pass; no test deleted or skipped.
**Validation:** `{{LOCAL_TEST_CMD}}` exits 0.
**Stop-and-fix:** standard. Do not patch tests to make red turn green.

Common forms of `{{LOCAL_TEST_CMD}}`:
| Stack | Example |
|---|---|
| ... | ... |
```

Notice it never repeats "Status legend" or the Stop-and-fix rule body — those live in `templates/Plan.md` and `templates/Implement.md`. The workflow file only fills in the parts that are workflow-specific.

## Handoff text

If your workflow needs a specific handoff phrasing (e.g. "your CI requires a different polling cadence"), put it at the bottom of the workflow file under `## Handoff overrides`. Otherwise the default in `SKILL.md -> Phase 4` applies.

## Example workflows worth writing

- `feat-implementation.md` — feature work with design doc step before M5
- `dependency-upgrade.md` — multi-package version bump with codemod + matrix tests
- `migration.md` — schema or framework migration with explicit rollback rehearsal as a milestone
- `incident-postmortem.md` — production hotfix with mandatory G0 (fix-forward vs revert decision) before M5
- `flaky-test-elimination.md` — bisect -> fix -> 100x re-run as milestones

PRs adding any of the above are welcome — see `../README.md -> Contributing`.
