#!/usr/bin/env bash
# codex-goal-handoff installer
#
# Installs the skill into every detected agent-skill location and
# enables the OpenAI Codex `features.goals` flag idempotently.
#
# Usage:
#   ./install.sh                  # interactive: install everywhere it can detect
#   ./install.sh --claude         # only ~/.claude/skills/
#   ./install.sh --agents         # only ~/.agents/skills/
#   ./install.sh --codex          # only ~/.codex/skills/
#   ./install.sh --dry-run        # show what would happen, do nothing
#   ./install.sh --uninstall      # remove all installed copies (config flag is left alone)
#
# Remote one-liner (after this repo is published):
#   curl -fsSL https://raw.githubusercontent.com/cskwork/codex-goal-handoff/main/install.sh | bash

set -euo pipefail

SKILL_NAME="codex-goal-handoff"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
UNINSTALL=0
TARGETS=()

# --------------------------- arg parsing ---------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --claude)     TARGETS+=("$HOME/.claude/skills") ;;
    --agents)     TARGETS+=("$HOME/.agents/skills") ;;
    --codex)      TARGETS+=("${CODEX_HOME:-$HOME/.codex}/skills") ;;
    --dry-run)    DRY_RUN=1 ;;
    --uninstall)  UNINSTALL=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2 ;;
  esac
  shift
done

# --------------------------- detection -----------------------------

# Always offer the three known locations; install only into ones where
# the parent (~/.claude, ~/.agents, ~/.codex) already exists.
if [ ${#TARGETS[@]} -eq 0 ]; then
  for parent in "$HOME/.claude" "$HOME/.agents" "${CODEX_HOME:-$HOME/.codex}"; do
    if [ -d "$parent" ]; then
      TARGETS+=("$parent/skills")
    fi
  done
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "No agent-skill parent directory found (~/.claude, ~/.agents, ~/.codex)." >&2
  echo "Create one first, or pass an explicit flag." >&2
  exit 1
fi

# --------------------------- helpers -------------------------------

# run cmd args...   — array form, no eval, dry-run safe.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'DRY-RUN:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

stamp() { date +%Y%m%d-%H%M%S; }

# Check whether `goals = true` is set inside the [features] block specifically
# (not in some other section like [profiles.dev.features]).
features_goals_enabled() {
  local cfg="$1"
  awk '
    /^\[/             { in_section = ($0 == "[features]") }
    in_section && /^[[:space:]]*goals[[:space:]]*=[[:space:]]*true[[:space:]]*$/ { found = 1 }
    END               { exit !found }
  ' "$cfg"
}

has_features_section() {
  grep -qE '^\[features\][[:space:]]*$' "$1"
}

# --------------------------- uninstall -----------------------------

if [ "$UNINSTALL" -eq 1 ]; then
  for parent in "${TARGETS[@]}"; do
    target="$parent/$SKILL_NAME"
    if [ -e "$target" ]; then
      echo "Removing: $target"
      run rm -rf "$target"
    else
      echo "Not present: $target"
    fi
  done
  echo "Done. (Codex config.toml goals flag left alone — remove manually if you want.)"
  exit 0
fi

# --------------------------- install -------------------------------

# 1) Copy skill tree into every target.
echo "Installing $SKILL_NAME into:"
for parent in "${TARGETS[@]}"; do
  target="$parent/$SKILL_NAME"

  # Refuse to install over our own running copy (would self-delete the source).
  if [ "$SCRIPT_DIR" = "$target" ]; then
    echo "  $target  (skipped — source and target are the same path)"
    continue
  fi

  run mkdir -p "$parent"
  if [ -e "$target" ]; then
    backup="$target.bak-$(stamp)"
    run mv "$target" "$backup"
    echo "  $target  (existing copy backed up to $backup)"
  else
    echo "  $target"
  fi
  run cp -R "$SCRIPT_DIR" "$target"
  # Drop the installer & VCS metadata from the installed copy.
  run rm -f "$target/install.sh"
  run rm -rf "$target/.git" "$target/.github"
done

# 2) Enable Codex `features.goals = true` idempotently.
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CFG="$CODEX_HOME_DIR/config.toml"

if [ -f "$CFG" ]; then
  if features_goals_enabled "$CFG"; then
    echo "Codex config: features.goals already enabled at $CFG"
  else
    echo "Codex config: enabling features.goals = true at $CFG"
    BAK="$CFG.bak-$(stamp)"
    run cp "$CFG" "$BAK"
    if has_features_section "$CFG"; then
      # Insert under existing [features] header.
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN: awk insert 'goals = true' under [features] in $CFG"
      else
        awk 'BEGIN{done=0}
             /^\[features\][[:space:]]*$/ && !done { print; print "goals = true"; done=1; next }
             { print }' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
      fi
    else
      # Append a fresh [features] section.
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY-RUN: append [features]\\ngoals = true to $CFG"
      else
        printf '\n[features]\ngoals = true\n' >> "$CFG"
      fi
    fi
    echo "  backup: $BAK"
  fi
else
  echo "Codex config not found at $CFG — skipping flag enable."
  echo "  Run \`codex --version\` to bootstrap, then re-run this installer."
fi

# 3) Final hints.
cat <<'EOF'

Installed.

Next:
  1. Verify ChatGPT auth (required for /goal — API-key auth does not work):
       codex login status     # expect "ChatGPT"
       # if not, run: codex login

  2. (Optional, only if using Claude Code) Install the Codex bridge plugin:
       /plugin marketplace add openai/codex-plugin-cc
       /plugin install codex@openai-codex
       /reload-plugins

  3. Try the skill:
       - In Claude Code:   ask "use codex-goal-handoff to fix ticket PROJ-123"
       - In Codex CLI:     `codex` then `/goal pursue the goal at .codex-goals/PROJ-123/Prompt.md`

  4. Skill files live at:
EOF
for parent in "${TARGETS[@]}"; do
  echo "       $parent/$SKILL_NAME/"
done
