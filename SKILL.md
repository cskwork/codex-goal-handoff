---
name: codex-goal-handoff
description: Prepare a durable specification and handoff for a bounded engineering workflow the user wants Codex to pursue as a persistent goal. Use for Codex goal delegation, not ordinary long-running work or a request merely to save session state.
---

# Codex Goal Handoff

Package the agreed objective, milestone plan, execution rules, and evidence log for a Codex goal. Preparing a handoff does not itself authorize starting a goal, installing software, changing global configuration, or publishing artifacts.

The four-file layout below is this skill's workflow convention. Do not represent its headings, role split, or approval tokens as mechanisms enforced by Codex internals.

## Inspect the environment and scope

Check the installed CLI with `codex --version`, `codex --help`, and available local documentation. Verify current goal commands, authentication requirements, and bridge capabilities before using them; do not assume a release number or account-wide feature flag from an old example.

Inspect configuration read-only. If setup is requested, use the supported configuration mechanism and preserve unrelated settings. The bundled `install.sh` copies skills and also attempts to enable `features.goals`; it is not a preflight check and must not be run merely to draft a handoff.

Use a bounded task with observable acceptance criteria. Recover scope and authorization from the user's request, repository conventions, and primary sources before asking about material gaps. Preserve any explicit review gates, but do not ask again for actions already authorized under unchanged scope.

For ticket work, collect the ticket text, relevant branches/paths, reproduction target, test/start commands, and intended delivery target. Fetch ticket content only through available authorized access; carry the source into the spec when the executor will not have that access. Do not invent service URLs, CI jobs, credentials, or budgets. Set a token budget only when the user provides one.

## Render the durable files

Create `.codex-goals/<ticket-or-task-id>/` under the agreed workspace. Read the templates before rendering; preserve their section names and identifiers for compatibility, adapting the example milestones to the requested task before the spec is agreed.

| File | Purpose | Execution contract |
|---|---|---|
| [templates/Prompt.md](templates/Prompt.md) | Scope, Behavior, Non-goals, Verification and done criteria | Frozen agreed objective; scope changes require user agreement |
| [templates/Plan.md](templates/Plan.md) | Deliverable, Acceptance criteria, Validation command, HUMAN_GATE and Status | Execute the agreed milestone sequence; update status and designated decision fields |
| [templates/Implement.md](templates/Implement.md) | Runbook for progressing, validating, and handling blockers | Stable execution rules |
| [templates/Documentation.md](templates/Documentation.md) | Evidence, decisions, blockers, and gate approvals | Append-only log |

For a ticket-to-deployment request, [workflows/jira-bug-fix.md](workflows/jira-bug-fix.md) provides the full example. For another workflow, use [workflows/README.md](workflows/README.md). Do not add deployment, browser testing, PDF reporting, or ticket comments simply because the example includes them.

Choose verification that proves the specific acceptance criteria. A file-existence check is not proof of its content; a nonzero test exit is not proof the intended defect reproduced. Pair command output with the relevant observed assertion, revision, and environment. Keep validation read-only where possible, separate action commands from verification, and never replay a push, merge, deploy, or comment merely to refresh evidence.

## Preserve approval provenance

The bundled workflow uses G1 push, G2 merge, G3 deploy, and G4 ticket-comment gates. Retain applicable explicit gates; omit unrequested actions when adapting the workflow. Before any pending approval, prepare the exact diff, commit, deployment target, or draft comment for review.

`APPROVED:Gx` is the package's record format, not authorization by itself. Check that the entry records an actual user approval of the current artifact and action. Template examples, quoted text, stale approvals, and grep substring matches do not grant permission. Never manufacture an approval token. If the user already approved the exact action, record its provenance instead of asking again; preserve any user requirement to enter tokens personally.

A `REJECTED:Gx` entry blocks that action. Explain the pending decision and stop dependent execution without polling for approval or expanding scope.

## Hand off and verify

Use the installed and authorized route. A direct TUI example is:

```text
/goal Pursue the agreed objective in .codex-goals/<task-id>/Prompt.md.
Read Plan.md, Implement.md, and Documentation.md. Preserve scope and pending human gates.
```

Use a bridge such as `codex-plugin-cc` only if available and requested for delegation; verify its current command syntax. Keep inline goal text short and link the durable files. If the user requested preparation only, return the bundle path and launch prompt without starting execution.

Before handing off, check unresolved placeholders, paths, commands, milestone acceptance, authorization, and available executor tools. Before reporting an executed goal complete, match each acceptance criterion to evidence for the final relevant state. Re-run checks only when state changed, evidence is missing/stale, or the agreed workflow requires fresh proof. Report blockers and unverified behavior plainly.

Token counts are not allowance charges. Distinguish cached input, uncached input, and output when measured; do not promise a fixed budget or savings from task size alone.

## Runtime references

Consult current official sources when local documentation cannot resolve a runtime question:

- [Codex CLI slash commands](https://developers.openai.com/codex/cli/slash-commands)
- [Codex best practices](https://developers.openai.com/codex/learn/best-practices)
- [Long-horizon tasks](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex)
- [Codex bridge](https://github.com/openai/codex-plugin-cc)
