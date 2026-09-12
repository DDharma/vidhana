#!/usr/bin/env bash
# Deterministic wiki checks. No model call. Exit 1 on any finding. Run from the kit root.
#  1 every [[link]] resolves      2 every page indexed exactly once      3 no orphan pages
#  4 no moving values in prose    5 log.md entries match the prefix     6 no page writes outside wiki/ (n/a)
set -u
root="${CLAUDE_PROJECT_DIR:-$PWD}"; W="$root/wiki"; findings=0
out=$(mktemp); say(){ echo "LINT: $*" | tee -a "$out"; }
[ -d "$W" ] || { echo "LINT: no wiki/ directory"; exit 1; }
pages=$(cd "$W" && find . -name '*.md' | sed 's|^\./||; s|\.md$||' | sort)

# 1 links resolve
while IFS= read -r f; do
  sed 's/<!--.*-->//g' "$W/$f.md" | grep -o '\[\[[^]|#]*' 2>/dev/null | sed 's/\[\[//' | while IFS= read -r l; do
    [ -z "$l" ] && continue; [ -f "$W/$l.md" ] || say "broken link [[${l}]] in $f.md"
  done
done <<< "$pages"

# 2 indexed exactly once (index itself and log are exempt)
while IFS= read -r f; do
  case "$f" in index|log) continue;; esac
  n=$(grep -c "\[\[$f\]\]" "$W/index.md" 2>/dev/null || echo 0)
  [ "$n" = 1 ] || say "$f.md appears $n times in index.md (want 1)"
done <<< "$pages"

# 3 orphans: pages with no inbound link from any page other than index (index/log/overview exempt)
while IFS= read -r f; do
  case "$f" in index|log|overview|gotchas|open-questions) continue;; esac
  n=0; while IFS= read -r g; do case "$g" in index|"$f") continue;; esac
    sed 's/<!--.*-->//g' "$W/$g.md" | grep -q "\[\[$f\]\]" && n=$((n+1)); done <<< "$pages"
  [ "$n" -gt 0 ] || say "orphan: $f.md has no inbound link outside index.md"
done <<< "$pages"

# 4 moving values in prose (skip log.md and items/, which are historical records)
while IFS= read -r f; do
  case "$f" in log|items/*) continue;; esac
  grep -nE '\b[0-9a-f]{7,40}\b' "$W/$f.md" | grep -viE 'NOT VERIFIED|superseded' | while IFS= read -r hit; do
    echo "$hit" | grep -qE '[0-9]' && echo "$hit" | grep -qE '[a-f]' && say "possible SHA in $f.md: ${hit:0:70}"
  done
  grep -nE '\bthe (two|three|four|five|six|seven|eight|nine|ten|[0-9]+) (modules|rules|files|steps|endpoints|tables|pages)\b' "$W/$f.md" | while IFS= read -r hit; do
    say "copied count in $f.md: ${hit:0:70}"; done
done <<< "$pages"

# 5 log prefix
grep -n '^## ' "$W/log.md" | grep -vE '^[0-9]+:## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\] (ingest|lint|init) \| ' | while IFS= read -r hit; do
  say "bad log heading: ${hit:0:70}"; done

n=$(wc -l < "$out"); rm -f "$out"
if [ "$n" -gt 0 ]; then echo "vidhana wiki-lint: $n finding(s)"; exit 1; else echo "vidhana wiki-lint: clean"; exit 0; fi
