# Folder Structure with the LLM Wiki

This document describes the kit's layout once Karpathy's LLM-Wiki pattern is added as a memory layer for the pipeline. Pattern source: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f. Status: **built into the repository root** on 2026-09-13. Gate self-test 17/17 (current, including the later designer cases), `wiki-lint.sh` clean on the skeleton and catching all six planted defects. What remains is the on-your-machine part (Test Guide section W). The permission-precedence question in §5 was resolved by putting the fence in every other agent's `disallowedTools` rather than a project-level deny; W1 confirms it on your version.

Legend in trees: `+` new file or folder · `~` existing file that changes · unmarked = unchanged from the current kit.

---

## 1. The three layers, mapped onto the kit

The gist describes three layers. They map one-to-one onto folders that already exist or are added:

| Gist layer | Who writes | Who reads | In this kit |
|---|---|---|---|
| Raw sources — immutable inputs | pipeline agents | librarian | `pipeline/` (specs, plans, reviews, qa, reports) |
| The wiki — LLM-maintained markdown | librarian only | spec, planner, humans | `wiki/` |
| The schema — how to maintain it | you (rarely) | librarian | `CLAUDE.md` § WIKI SCHEMA + `.claude/rules/wiki-conventions.md` |

Writes go one direction: `pipeline/ → wiki/`. Nothing in the pipeline reads `wiki/` except spec and planner, and nothing writes `wiki/` except the librarian. Both facts are enforced in `settings.json`, not just requested in prompts.

---

## 2. Full tree

```
project-root/
├── CLAUDE.md                        ~ 3 editable lines + PIPELINE CONTRACT + WIKI SCHEMA (new section)
├── README.md
│
├── .claude/
│   ├── settings.json                ~ Write/Edit on wiki/** allowed only inside librarian; denied elsewhere
│   ├── agents/
│   │   ├── orchestrator.md          ~ adds Agent(librarian); contract step 7 = ingest after DONE/BLOCKED
│   │   ├── spec.md                  ~ reads wiki/index.md first, then pages, then source
│   │   ├── planner.md               ~ same, and must read wiki/gotchas.md before writing a plan
│   │   ├── plan-reviewer.md
│   │   ├── builder.md
│   │   ├── qa.md
│   │   ├── reviewer.md
│   │   ├── librarian.md             + sonnet · ingest one item, or lint the wiki · sole writer of wiki/
│   │   └── ship.md
│   ├── hooks/
│   │   ├── gate.sh                  ~ +1 case: librarian may not stop until wiki/log.md gained a line
│   │   └── sync-reports.sh          ~ also syncs wiki/ to the bucket
│   └── rules/
│       └── wiki-conventions.md      + page templates, link rules, no-copied-state rule, NOT VERIFIED tag
│
├── pipeline/                        ── RAW SOURCES · written once by pipeline agents · never edited after
│   ├── queue.md
│   ├── state.json
│   ├── specs/      <id>.md
│   ├── plans/      <id>.md
│   ├── reviews/    <id>-plan-rN.md   <id>-code-rN.md
│   ├── qa/         <id>-rN.md
│   └── reports/    <id>.md   <id>-build.md
│
├── wiki/                            ── THE WIKI · librarian writes · humans and spec/planner read
│   ├── index.md                     + one line per page, grouped by section; the entry point for all readers
│   ├── log.md                       + append-only; every line starts  ## [YYYY-MM-DD] ingest|lint | <id> <title>
│   ├── overview.md                  + what the system is; how to run and test it; current shape
│   ├── modules/                     + one page per module or top-level source directory
│   │   └── <module>.md
│   ├── decisions/                   + one page per non-obvious choice a plan made (ADR-style)
│   │   └── <yyyy-mm-dd>-<slug>.md
│   ├── items/                       + one summary page per pipeline item, linking to its raw artifacts
│   │   └── <id>.md
│   ├── gotchas.md                   + recurring QA and review findings; the planner reads this first
│   └── open-questions.md            + contradictions and gaps lint found that no source resolves
│
└── tests/
    ├── gate-selftest.sh             ~ +1 case for the librarian
    └── wiki-lint.sh                 + deterministic checks, no model call: broken links, orphans, index drift
```

---

## 3. What each wiki file is for

### `wiki/index.md`
The catalog. Every page in the wiki appears here exactly once with a link and a one-line description, grouped by section (`overview`, `modules`, `decisions`, `items`, `gotchas`, `open-questions`). Spec and planner open this file first, choose 2–4 pages, and only then read source. If they keep reading the whole repo anyway, the one-line descriptions are too vague — that is the tuning knob.

```markdown
# Index
## Modules
- [[modules/auth]] — login, sessions, password reset; touched by F-001, B-002
- [[modules/items-api]] — CRUD + pagination on /items; touched by F-002
## Decisions
- [[decisions/2026-09-13-token-expiry-30min]] — reset tokens expire at 30 min, not 24 h
## Items
- [[items/F-001]] — password reset via email · DONE · plan 1 / qa 2 / review 1
```

### `wiki/log.md`
Append-only chronology. Fixed prefix so it's greppable without a model: `grep "^## \[" wiki/log.md | tail -5`. Every librarian run adds at least one entry; the gate hook checks that the line count grew.

```markdown
## [2026-09-13] ingest | F-001 password reset via email
Updated modules/auth, created decisions/2026-09-13-token-expiry-30min, created items/F-001, +1 gotcha.
## [2026-09-13] lint | 5-item pass
2 orphan pages linked; 1 contradiction moved to open-questions.
```

### `wiki/overview.md`
The page a new reader (human or agent) opens to understand the system. Kept short. Rewritten, not appended, when the shape changes.

### `wiki/modules/<module>.md`
Template:
```markdown
# <module>
**Purpose** — one paragraph.
**Key files** — links into the repo (paths only, never line numbers).
**Invariants** — things that must stay true; each cites where it was established.
**Gotchas** — mistakes QA/review caught here, each linking to the review file.
**History** — items that touched this module: [[items/F-001]], [[items/B-002]]
```

### `wiki/decisions/<date>-<slug>.md`
Created only when a plan chose between real alternatives. Context · decision · consequences · `superseded-by:` (never deleted; a reversed decision gets a pointer to its replacement).

### `wiki/items/<id>.md`
One per pipeline item, written from the item's raw artifacts. What was asked · what was built · rounds used per gate · what QA and review caught · open risks · links to every raw file under `pipeline/`. This page is where the pipeline's paperwork becomes searchable memory.

### `wiki/gotchas.md`
The most valuable page for cost. Recurring findings across items ("tests must mock the clock", "migrations need the down step"). The planner reads it before writing any plan, which stops the QA→replan loop from rediscovering the same thing on every item.

### `wiki/open-questions.md`
Where lint parks contradictions between pages and claims no source supports. The librarian never resolves these by guessing; a later item's spec can.

---

## 4. The rules (schema layer)

These go in `CLAUDE.md` under a `# WIKI SCHEMA` heading and, at length, in `.claude/rules/wiki-conventions.md`.

1. **Provenance on every claim.** A wiki statement links to the `pipeline/` file or commit it came from. Anything the librarian infers rather than reads is tagged `NOT VERIFIED`. This is the mitigation for the "hallucinations become permanent facts" failure reported repeatedly in the gist's comment thread.
2. **Shape, not values.** Pages describe how something is structured, never a value that moves — no line counts, no current SHA, no "the five modules". Link to the live thing. `wiki-lint.sh` greps prose for hex SHAs and bare counts and fails on them.
3. **Never delete, supersede.** Wrong pages get `superseded-by:` and stay linked. Refuted claims remain visible as dead ends.
4. **Index is complete and unique.** Every page in exactly one index section. `wiki-lint.sh` diffs the file tree against `index.md`.
5. **Log before stop.** An ingest or lint that added no log line did not happen; the gate hook enforces it.
6. **One writer.** Only `librarian` has `Write(./wiki/**)`. Spec, planner, builder, qa, reviewer are denied it in `settings.json`.

---

## 5. Changes to existing files

### `CLAUDE.md` — add step 7 and the schema
```markdown
7 librarian     → wiki/items/<id>.md + updated wiki/index.md + new line in wiki/log.md
                  runs after every DONE or BLOCKED; runs `lint` every 5 items
# WIKI SCHEMA
Raw sources live in pipeline/ and are never edited. The wiki lives in wiki/ and is written only by
the librarian agent following .claude/rules/wiki-conventions.md. Spec and planner read wiki/index.md
before reading source. See rules 1–6 in that file.
```

### `.claude/agents/librarian.md`
```markdown
---
name: librarian
description: Ingests one finished pipeline item into wiki/, or runs a lint pass over the wiki. The only agent that writes wiki/.
model: sonnet
tools: Read, Glob, Grep, Write, Edit, Bash(git log *), Bash(git diff *), Bash(bash tests/wiki-lint.sh)
maxTurns: 80
---
Mode ingest <id>: read every pipeline/ file for <id>. Create wiki/items/<id>.md. Update each touched
modules/ page. Create a decisions/ page if the plan chose between alternatives. Add recurring findings
to gotchas.md. Rebuild index.md. Append one log.md line. Run tests/wiki-lint.sh; fix what it reports.
Mode lint: read index.md and every page; move contradictions and unsupported claims to
open-questions.md; link orphans; append one log.md line. Never guess a resolution.
Every claim links to its source file. Tag inferences NOT VERIFIED. Never write a moving value.
```

### `.claude/agents/orchestrator.md`
- `tools:` gains `Agent(librarian)`.
- Body gains: "After writing pipeline/reports/<id>.md, spawn librarian in mode ingest <id>. Every 5th item, also spawn librarian in mode lint."

### `.claude/agents/spec.md` and `planner.md`
Add as the first line of the body: "Read wiki/index.md first. Open at most four wiki pages. Only then read source. Planner: also read wiki/gotchas.md."

### Wiki fence (as built)
A project-level `deny` on `wiki/**` would also block the librarian, so the fence lives in every other agent's frontmatter: `disallowedTools: Write(./wiki/**), Edit(./wiki/**)` on orchestrator, spec, planner, plan-reviewer, builder, qa, reviewer. The librarian is the only agent without it. Test Guide W1 confirms path patterns are honoured on your Claude Code version; fallback is a `PreToolUse` hook.

### `.claude/hooks/gate.sh`
```bash
  librarian)     need="$root/wiki/log.md"
                 before=$(cat "$root/pipeline/.log-lines" 2>/dev/null || echo 0)
                 after=$(grep -c '^## \[' "$need" 2>/dev/null || echo 0)
                 [ "$after" -gt "$before" ] || { echo "GATE: wiki/log.md gained no entry." >&2; exit 2; }
                 exit 0 ;;
```
The orchestrator writes the pre-run line count to `pipeline/.log-lines` before spawning the librarian.

### `tests/wiki-lint.sh` (deterministic, no tokens)
Checks: every `[[link]]` resolves to a file; every file under `wiki/` appears in `index.md` exactly once; no page has zero inbound links except `index.md` and `overview.md`; no 7–40-char hex string or "the N <things>" phrase in prose outside `log.md` and `items/`; `log.md` lines all match the prefix regex.

---

## 6. What this costs and what it saves

- **Adds** one sonnet session per item (ingest, small: it reads only that item's files) and one lint session per five items.
- **Saves** on spec and planner: they read `index.md` plus a few pages instead of scanning the repo. Whether the saving exceeds the cost is measurable — add an `ingest` column to the Test Guide L4 table and compare spec/planner token counts with and without the wiki on the same fixture.
- The gist's thread cites a paper putting query-side cost of this pattern at ~21× a RAG lookup; the same commenter notes the ingest figure in that paper over-counts by an order of magnitude. Treat both as "measure it", not as facts about your setup.

---

## 7. Deliberately left out of v1

- Search tooling (`qmd` or similar). The gist says the index is sufficient into the hundreds of pages; a pipeline wiki will not get there quickly.
- Obsidian. Useful for you to browse; irrelevant to the agents. The wiki is plain markdown with `[[wikilinks]]`, so it opens in Obsidian unchanged.
- Human review of ingests. The gist recommends it; this build has no humans. It's acceptable here because every source is the pipeline's own output rather than the open web, which is also why rule 1 (provenance) is non-negotiable.

---

## 8. Verification plan (now in test-guide.md, section W)

| Level | Check | Pass |
|---|---|---|
| L0 | `bash tests/wiki-lint.sh` on the empty skeleton | 0 findings |
| L0 | gate self-test gains the librarian case | 11 passed |
| L1 | run librarian alone on a finished fixture item | `items/<id>.md` exists; `index.md` lists it; `log.md` +1 line; lint clean |
| L1 | spec agent with a populated wiki | transcript shows `index.md` read before any source file |
| L3 | plant a contradiction across two module pages, run lint | it lands in `open-questions.md`, neither page is "fixed" by guessing |
| L3 | plant a bare SHA in a module page | `wiki-lint.sh` fails on it |
| L4 | same fixture item with and without wiki | spec+planner tokens compared; ingest cost recorded |
