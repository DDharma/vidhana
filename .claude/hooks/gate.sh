#!/usr/bin/env bash
# SubagentStop gate. Reads Claude Code hook JSON on stdin. Exit 2 = the subagent may NOT stop yet.
# Ref: code.claude.com/docs/en/hooks  (SubagentStop input carries agent_type; exit 2 prevents stopping)
# Fails CLOSED: if the JSON cannot be parsed, the subagent is blocked with an explanatory message.
set -uo pipefail
payload=$(cat)

json_get() {  # json_get '<json>' '<key>'  → value or empty
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -r --arg k "$2" '.[$k] // empty'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$1" | python3 -c 'import sys,json;d=json.load(sys.stdin);v=d.get(sys.argv[1],"");print("" if v is None else v)' "$2"
  else
    echo "GATE: neither jq nor python3 found; cannot verify artifacts. Install jq." >&2; exit 2
  fi
}

agent=$(json_get "$payload" agent_type); [ -z "$agent" ] && agent="${1:-}"
root="${CLAUDE_PROJECT_DIR:-$PWD}"           # stays on the main checkout even inside a worktree
state="$root/pipeline/state.json"
[ -s "$state" ] || exit 0
sjson=$(cat "$state")
id=$(json_get "$sjson" current_item); round=$(json_get "$sjson" round); round=${round:-1}

[ -z "$id" ] && [ "$agent" != librarian ] && exit 0   # no active item → nothing to gate (except lint)
case "$agent" in
  spec)          need="$root/pipeline/specs/$id.md" ;;
  designer)      need="$root/pipeline/designs/$id.md"
                 [ -s "$root/DESIGN.md" ] || { echo "GATE: DESIGN.md is missing or empty at the repo root. Write it, then stop." >&2; exit 2; } ;;
  planner)       need="$root/pipeline/plans/$id.md" ;;
  plan-reviewer) need="$root/pipeline/reviews/$id-plan-r$round.md" ;;
  builder)       need="$root/pipeline/reports/$id-build.md" ;;
  qa)            need="$root/pipeline/qa/$id-r$round.md" ;;
  reviewer)      need="$root/pipeline/reviews/$id-code-r$round.md" ;;
  librarian)     before=$(cat "$root/pipeline/.log-lines" 2>/dev/null || echo 0)
                 after=$(grep -c '^## \[' "$root/wiki/log.md" 2>/dev/null || echo 0)
                 [ "$after" -gt "$before" ] || { echo "GATE: wiki/log.md gained no entry. Append one, then stop." >&2; exit 2; }
                 exit 0 ;;
  *)             exit 0 ;;                    # orchestrator, ship, built-in agents: not gated
esac
if [ ! -s "$need" ]; then
  echo "GATE: required artifact $need is missing or empty. Write it, then stop." >&2; exit 2
fi
case "$agent" in
  plan-reviewer|qa|reviewer)
    grep -Eq '^VERDICT: (APPROVE|REVISE|PASS|FAIL)[[:space:]]*$' "$need" || {
      echo "GATE: $need must end with a line 'VERDICT: <APPROVE|REVISE|PASS|FAIL>'." >&2; exit 2; } ;;
esac
exit 0
