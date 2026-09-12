# Wiki Usage Guide — getting the most out of the project memory

The wiki is built and structurally tested (13/13 gate cases, lint clean, six planted defects caught). This guide is about *using* it well once it's running, and about what to change after your first tests. It assumes you've read `getting-started.md`.

---

## 1. What you do vs what the librarian does

| You | Librarian |
|---|---|
| Read `wiki/overview.md` to get oriented on a project you haven't touched in a while | Rewrites `overview.md` when the system's shape changes |
| Read `wiki/gotchas.md` before writing a queue item | Adds to it when QA or review catch the same class of thing twice |
| Read `wiki/items/<id>.md` instead of six raw files when reviewing an item | Writes it from the raw files, with links back to each |
| Read `wiki/open-questions.md` and resolve entries by queueing an item whose spec settles them | Parks contradictions there; never guesses |
| Run `bash tests/wiki-lint.sh` when something looks off | Runs it after every ingest and fixes what it reports |
| Delete a page if it's wrong beyond repair | Never deletes; supersedes with a pointer |

You never edit `wiki/` by hand except to delete. If you want something in the wiki, it has to come from a raw source — write a queue item, or drop a note in `pipeline/` and queue a `type: feature` item whose spec cites it.

---

## 2. Daily use

**Before writing a queue item.** Open `wiki/gotchas.md` and the module page for the area you're touching. If the gotcha you're about to trip is already there, mention it in the acceptance criteria — the planner will read it anyway, but naming it in the item makes QA test for it explicitly.

**After an item finishes.** Read `wiki/items/<id>.md` first, not the report. It is the report plus links to every raw file, plus what the item changed in the wiki's picture of the system. Then open the raw files it links only where you want detail.

**Reviewing the branch.** The module page's **Invariants** section is your checklist: did the diff break any of them?

**When the pipeline starts making the same mistake twice.** That is the signal the wiki isn't feeding back. Check: is it in `gotchas.md`? If not, the librarian didn't classify it as recurring — see §4. If it is, the planner isn't reading it — check the planner's transcript for `gotchas.md` in its first few reads.

**Browsing.** Open the repo in Obsidian and set `wiki/` as a vault, or just read the markdown. `[[links]]` resolve to `wiki/<path>.md`. The graph view shows hubs and orphans faster than the lint does.

---

## 3. What "good" looks like after five items

- `index.md` has one line per page and each line says something a reader could act on ("auth — sessions, reset tokens, rate limit; touched by F-001 B-002"), not "auth module".
- Every module the pipeline has touched has a page; modules it hasn't touched don't.
- `gotchas.md` has 2–6 entries, each with a link to the QA or review file that caught it.
- `decisions/` has fewer pages than items — not every item makes a decision.
- `log.md` has one `ingest` line per item and one `lint` line after the fifth.
- Spec and planner transcripts show `wiki/index.md` read before any source file, and 2–4 wiki pages total.

If you see instead: a page per file, a decision per item, twenty gotchas, or the planner reading twelve wiki pages — the librarian is over-producing. Tighten as in §4.

---

## 4. Tuning after your first tests

These are the knobs, in the order you're most likely to need them.

### The index one-liners (most common fix)
If spec/planner still read the whole repo, `index.md` descriptions are too vague. Add to `wiki-conventions.md` under rule 4: *"Each index line names the concrete concerns the page covers and the item ids that touched it."* The librarian follows the conventions file, so changing the file changes behaviour without touching the agent.

### Over-production
Add to the librarian prompt: *"A module page exists only for a directory with more than one file the pipeline has changed. A decision page exists only when the plan text contains 'instead of', 'alternative', or 'chose'."* Deterministic triggers beat judgment here.

### Gotchas that aren't recurring
Change the rule to require two occurrences: *"Add to gotchas.md only when the same class of finding appears in two different items, or twice within one item's QA rounds. Otherwise leave it on the item page."*

### The lint pass is too rare or too often
`orchestrator.md`: "Every 5th completed item" — change the number. For a busy queue, 10; for a new project where the shape is settling, 3.

### Model choice
The librarian is on sonnet because ingest is mostly summarisation with strict rules. If W3 (provenance check) shows invented claims, move it to opus for ingest and keep sonnet for lint — split by adding a second agent `librarian-lint` or by putting `model:` selection in the orchestrator prompt. Measure first; sonnet is usually adequate here and opus doubles the per-item wiki cost.

### The fence didn't hold (W1 failed)
Add to `settings.json`:
```json
"PreToolUse": [{ "matcher": "Write|Edit", "hooks": [{ "type": "command",
  "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/wiki-fence.sh", "args": [] }] }]
```
with `wiki-fence.sh` reading `tool_input.file_path` and `agent_type` from stdin and exiting 2 when the path is under `wiki/` and the agent is not `librarian`. Both fields are in the documented hook input.

### It costs more than it saves (W4 failed)
Before removing anything: (1) fix the index one-liners, (2) cap spec/planner at "at most two wiki pages" instead of four, (3) rerun W4. The saving comes from *not* reading source; if the wiki pages are long the agents read both. If it still loses, keep the wiki for humans and remove the read-first line from `spec.md`/`planner.md` — the librarian still costs one small session per item and you still get the paper trail.

---

## 5. Using the wiki beyond the pipeline

- **Onboarding.** A new teammate reads `overview.md`, then the module pages, then the last ten `items/`. That is a better tour than the git log.
- **Bug triage.** Before queueing a `type: bug` item, grep `wiki/` for the symptom; often an `items/` page or a gotcha already explains the area.
- **Asking questions.** In a normal `claude` session (not the orchestrator): "Using wiki/index.md, explain how sessions expire and which items changed it." Good answers can be filed back — queue a trivial item whose spec is the question, and the librarian will produce an `items/` page for it. That's the gist's "answers become pages" idea applied to a codebase.
- **Retro material.** `log.md` plus the rounds column in `items/` pages tells you which areas cause replans. That is a prioritised tech-debt list you didn't have to write.

---

## 6. What the wiki does not protect you from

- **Confidently wrong pages.** The lint checks links, index, orphans, moving values, and log format. It cannot check that "sessions expire after 30 minutes" is true. Provenance links are the defence: if a claim has no link, it's tagged `NOT VERIFIED` and you should treat it that way.
- **Drift after manual code changes.** The librarian only sees what the pipeline produced. If someone commits directly to `main`, the wiki doesn't know. Either route changes through the queue, or queue a `type: feature` item titled "reconcile wiki with commits since <date>" whose spec is `git log`.
- **Scale.** Around a few hundred pages the index stops being enough and you'd add search (the gist suggests `qmd`). A pipeline wiki takes a long time to get there.

---

## 7. First-week checklist

```markdown
- [ ] Ran 3 items; read all 3 wiki/items/ pages; every claim traceable (W2, W3)
- [ ] Rewrote index one-liners once and re-ran W4; wrote the net-token number here: ____
- [ ] gotchas.md has entries and the 4th item's plan referenced one (W7)
- [ ] Ran lint by hand once and read open-questions.md
- [ ] Opened wiki/ in Obsidian graph view; no unexpected orphans
- [ ] Decided the lint cadence (currently 5) and the librarian model (currently sonnet)
```
