#!/usr/bin/env bash
# PreToolUse fence for Vidhana pipeline agents.
# Exists because path-scoped entries in an agent's `disallowedTools` are parsed as the BARE tool
# name and strip the whole tool (verified 2026-09-14). All path and command fencing lives here.
# Exit 2 = deny the tool call. The main session (no agent_type) is never fenced.
set -uo pipefail
deny() { echo "FENCE: $*" >&2; exit 2; }

if   command -v jq      >/dev/null 2>&1; then parser=jq
elif command -v python3 >/dev/null 2>&1; then parser=python3
else deny "neither jq nor python3 found; cannot verify tool calls."; fi

get() {
  if [ "$parser" = jq ]; then printf '%s' "$1" | jq -er --arg k "$2" '(getpath($k|split("."))//"")|tostring'
  else printf '%s' "$1" | python3 -c 'import sys,json;d=json.load(sys.stdin)
k=sys.argv[1].split(".")
for part in k: d = d.get(part) if isinstance(d,dict) else None
print("" if d is None else d)' "$2"; fi
}

p=$(cat)
agent=$(get "$p" agent_type 2>/dev/null) || deny "hook input is not valid JSON; refusing the tool call."
[ -z "$agent" ] && exit 0                       # main session, not a pipeline agent

tool=$(get "$p" tool_name       2>/dev/null)
path=$(get "$p" tool_input.file_path 2>/dev/null)
cmd=$( get "$p" tool_input.command   2>/dev/null)
root="${CLAUDE_PROJECT_DIR:-$PWD}"
rel=${path#"$root"/}; rel=${rel#./}

case "$tool" in
  Write|Edit|NotebookEdit)
    case "$rel" in
      .claude/*)        deny "no agent may modify .claude/ (tried $rel)." ;;
      pipeline/queue.md) deny "the queue is human-owned (tried $rel)." ;;
    esac
    case "$agent" in
      librarian) case "$rel" in wiki/*) ;; *) deny "librarian writes only under wiki/ (tried $rel)." ;; esac ;;
      designer)  case "$rel" in CLAUDE.md) deny "designer may not edit CLAUDE.md." ;; esac ;;
      qa)        case "$rel" in pipeline/qa/*) ;; *) deny "qa writes only its report under pipeline/qa/ (tried $rel)." ;; esac ;;
      *)         case "$rel" in
                   wiki/*)    deny "only the librarian writes wiki/ (tried $rel)." ;;
                   DESIGN.md) deny "only the designer writes DESIGN.md." ;;
                 esac ;;
    esac ;;
  Bash)
    printf '%s' "$cmd" | grep -Eq '\bgit\b[^|;&]*\bpush\b'            && deny "git push is not allowed."
    printf '%s' "$cmd" | grep -Eq '\bgit\b[^|;&]*\bmerge\b'           && deny "git merge is not allowed."
    printf '%s' "$cmd" | grep -Eq '\bgit\b[^|;&]*reset[^|;&]*--hard'  && deny "git reset --hard is not allowed."
    printf '%s' "$cmd" | grep -Eq '\bgit\b[^|;&]*branch[^|;&]*-D'     && deny "deleting branches is not allowed."
    printf '%s' "$cmd" | grep -Eq '\brm[[:space:]]+-[a-zA-Z]*[rR]'    && deny "recursive rm is not allowed."
    printf '%s' "$cmd" | grep -Eq '(^|[[:space:]/])\.env([.[:space:]]|$)' && deny ".env is not readable by pipeline agents."
    [ "$agent" = librarian ] || printf '%s' "$cmd" | grep -Eq '(>|>>|\btee\b|\bsed[[:space:]]+-i|\bmv\b|\bcp\b|\btruncate\b)[^;&|]*[[:space:]]wiki/' \
      && [ "$agent" != librarian ] && deny "only the librarian writes wiki/."
    [ "$agent" = qa ] && printf '%s' "$cmd" | grep -Eq '\bsed[[:space:]]+-i|\bperl[[:space:]]+-[a-z]*i' \
      && deny "qa may not modify files."
    ;;
esac
exit 0
