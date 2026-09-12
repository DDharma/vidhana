#!/usr/bin/env bash
# Installs the two skill libraries the pipeline depends on. Idempotent. Safe to run from a SessionStart hook.
#   gstack      → ~/.claude/skills/gstack  (global install is the only path its author supports)
#   superpowers → Claude Code plugin from the official marketplace
set -uo pipefail
GS="$HOME/.claude/skills/gstack"
if [ ! -x "$GS/bin/gstack-session-kind" ]; then
  echo "bootstrap: installing gstack" >&2
  git clone -q --single-branch --depth 1 https://github.com/garrytan/gstack.git "$GS" 2>/dev/null || true
  (cd "$GS" && ./setup >/dev/null 2>&1) || echo "bootstrap: gstack setup reported an error; run ./setup manually" >&2
fi
if command -v claude >/dev/null 2>&1 && ! claude plugin list 2>/dev/null | grep -q superpowers; then
  echo "bootstrap: installing superpowers plugin" >&2
  claude plugin install superpowers@claude-plugins-official >/dev/null 2>&1 || echo "bootstrap: run '/plugin install superpowers@claude-plugins-official' inside claude" >&2
fi
command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || echo "bootstrap: WARNING neither jq nor python3 found; the gate hook will fail closed" >&2
exit 0
