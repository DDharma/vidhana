#!/usr/bin/env bash
# Proves .claude/hooks/gate.sh behaves as documented. Run from the kit root:  bash tests/gate-selftest.sh
# Uses a scratch copy so it never touches your real pipeline/ folder.
set -u
src=$(cd "$(dirname "$0")/.." && pwd); tmp=$(mktemp -d); cp -r "$src/.claude" "$tmp/"; mkdir -p "$tmp"/pipeline/{specs,plans,reviews,qa,reports}
cd "$tmp"; G=.claude/hooks/gate.sh; pass=0; fail=0
t(){ printf '{"hook_event_name":"SubagentStop","agent_type":"%s"}' "$2" | CLAUDE_PROJECT_DIR=$PWD bash $G >/dev/null 2>&1; rc=$?
     if [ "$rc" = "$3" ]; then pass=$((pass+1)); printf 'PASS  %-46s exit=%s\n' "$1" "$rc"; else fail=$((fail+1)); printf 'FAIL  %-46s exit=%s (want %s)\n' "$1" "$rc" "$3"; fi; }
echo '{"current_item":"T-001","round":1}' > pipeline/state.json
t "builder, no artifact → block"            builder 2
echo done > pipeline/reports/T-001-build.md
t "builder, artifact present → allow"       builder 0
t "qa, no artifact → block"                 qa 2
printf 'checked\n' > pipeline/qa/T-001-r1.md
t "qa, no VERDICT line → block"             qa 2
printf 'checked\nVERDICT: FAIL\n' > pipeline/qa/T-001-r1.md
t "qa, VERDICT present → allow"             qa 0
echo '{"current_item":"T-001","round":2}' > pipeline/state.json
t "qa round 2, only r1 exists → block"      qa 2
t "orchestrator → never gated"              orchestrator 0
t "ship → never gated"                      ship 0
echo '{}' > pipeline/state.json
t "no active item → allow"                  builder 0
echo '{"current_item":"T-001","round":1}' > pipeline/state.json
rc=$( (cd /tmp && printf '{"agent_type":"builder"}' | CLAUDE_PROJECT_DIR=$tmp bash $tmp/$G >/dev/null 2>&1; echo $?) )
if [ "$rc" = 0 ]; then pass=$((pass+1)); echo "PASS  worktree: cwd elsewhere, PROJECT_DIR=main → allow  exit=0"; else fail=$((fail+1)); echo "FAIL  worktree case exit=$rc"; fi
mkdir -p wiki; printf '# Log\n## [2026-09-13] init | skeleton\n' > wiki/log.md; echo 1 > pipeline/.log-lines
t "librarian, log unchanged → block"     librarian 2
printf '## [2026-09-13] ingest | T-001 x\n' >> wiki/log.md
t "librarian, log grew → allow"          librarian 0
echo '{}' > pipeline/state.json; echo 2 > pipeline/.log-lines
t "librarian lint mode, no item, no log → block" librarian 2
echo; echo "vidhana gate-selftest: $pass passed, $fail failed  (parser: $(command -v jq >/dev/null && echo jq || echo python3))"; rm -rf "$tmp"; [ $fail = 0 ]
