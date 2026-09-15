---
name: vidhana-queue
description: Generate or extend pipeline/queue.md for a Vidhana pipeline — slicing a PRD, a feature description or a bug report into small, independently shippable work items with mechanically checkable acceptance criteria. Use when seeding a new queue, adding features to an existing project, or converting a PRD into pipeline items.
argument-hint: "[path/to/prd.md | \"what you want built\"]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls *), Bash(cat *), Bash(grep *), Bash(sed *), Bash(find *), Bash(git *)
---

# Vidhana — build the queue

You are writing work items into `pipeline/queue.md`. Each item becomes one full pipeline run:
spec → (designer) → plan → plan-review → build → QA → code review → report → wiki.

`$ARGUMENTS` may be a path to a PRD, or a plain description of what to build. If empty, ask
what they want built and whether a PRD exists.

## The one rule that matters most

**One item = one observable behaviour, about an hour of pipeline time.**

This is not a style preference. An oversized item produces an oversized spec, which produces an
oversized plan, which every downstream agent then re-reads — the cost compounds. A single item
covering a whole app has been measured at 5+ hours with a 41 KB plan, against 4 minutes of actual
code generation. Small items are the difference between a pipeline you can use and one you can't.

Smaller items also give you checkpoints: you can read item 2's output and abort before paying
for items 3 through 8.

### Sizing test

An item is the right size when:

- It has **3 to 6** acceptance criteria. More than 6 means split it.
- Every criterion is a **command someone can run** with a stated expected result.
- When it is done, `<test command>` passes and the app still works. No item leaves the tree broken.
- One sentence describes it without using "and then".

If you cannot name the single behaviour an item adds, it is two items.

## Step 1 — Read the ground truth

Run these with Bash and read the output:

```bash
grep -n '^STACK:' CLAUDE.md
grep -c '^## item:' pipeline/queue.md
ls pipeline/reports/
ls wiki/index.md
```

Interpret it yourself: no `STACK:` line at all, or a STACK line still containing `<`, both mean
the project block is unconfigured.

`grep` exits non-zero when it finds nothing and `ls` exits non-zero on a missing path. That is
**data, not a failure** — "no such file or directory" for `wiki/index.md` means this project has no
memory layer yet, which is exactly what you needed to know. Never retry or abort on those.

**If there is no STACK line — or it is still the `<placeholder>` the kit ships with — stop.**
Tell the user to run `/vidhana-project` first. Without a real test command you cannot tell what a
checkable acceptance criterion looks like for this project, and every item you write will be guesswork.

Never duplicate an existing item id. Never re-queue an item that already has a report.

### Knowing what already exists

You must slice against reality, not against the PRD's assumptions. How you learn reality depends
on the project:

**Vidhana project with history** — read `wiki/index.md`, then at most four pages it points to.
That is what the wiki is for; it is cheaper and more current than reading source.

**Existing project with no wiki** (adopting Vidhana into a live codebase) — there is no memory
layer yet, so read the code:

```bash
ls -a
cat package.json
find src lib app -maxdepth 2 -type f
ls test tests spec __tests__
```

Identify the entry point, the module boundaries and the existing test layout. Then state plainly
in your report which parts of the PRD are **already built** — queuing work that exists is the most
expensive mistake this command can make.

**Empty repo** — nothing to read. The first item is `type: greenfield`.

## Step 2 — Slice

Work out the dependency order, then write items top to bottom in that order. The orchestrator
processes them in file order and will not start item N+1 until item N has a report.

**Greenfield.** The first item is scaffold plus one thin vertical slice that actually runs —
project file, test harness, and the single simplest end-to-end behaviour. Not "the data layer":
something a person can execute. Every later item adds one behaviour on top.

**Existing project.** One item per user-visible behaviour. If a change touches storage and an
endpoint and a screen, that is still one item if it is one behaviour — but it is three items if
it is three behaviours that happen to share a file.

Never use `type: greenfield` in a repo that already has code — it tells the spec agent to invent
scaffolding and tooling that already exist. Use `feature`, and let the spec cite the real files.
Add `existing tests still pass` as a criterion on every item in a live codebase; it is the cheapest
regression guard you have.

**Bugs.** One item per bug, `type: bug`, and a `repro:` line with exact steps, actual result and
expected result. Without a runnable repro the investigation step has nothing to reproduce.

## Step 3 — Write the items

Exact format the kit parses:

```markdown
## item: G-001
type: greenfield
layer: backend
title: One sentence, imperative, no "and"
acceptance:
- a command someone can run, and what it must return
- another one
- existing tests still pass
```

Fields:

| Field | Values | Notes |
|---|---|---|
| `type:` | `greenfield` `feature` `bug` `design-sync` | `greenfield` only for the first item of an empty repo |
| `layer:` | `backend` `frontend` `fullstack` | `backend` skips the designer. Omit and the spec agent decides |
| `title:` | one line | |
| `acceptance:` | 3–6 bullets | each must be executable |
| `repro:` | bugs only | exact steps, actual vs expected |
| `design:` | optional | Figma frame URL for this item's screens |

Id convention: `G-` greenfield, `F-` feature, `B-` bug, numbered in queue order.

### Acceptance criteria — the quality bar

QA verifies each criterion by **running a command and pasting the output**. A criterion it
cannot execute cannot pass.

- Good: ``GET /items?tag=x returns only items carrying tag x; a test covers a hit and a miss``
- Good: ```node cli.js add "milk"` prints the new item's number and exits 0``
- Bad: `search should be faster` — no command, no threshold
- Bad: `the code should be clean` — not observable
- Bad: `handles errors gracefully` — name the error and the response

Keep criteria **behavioural**. Visual detail belongs to the designer, not the queue —
for a frontend item say "the list shows an empty state", not "the empty state is centred with 24px padding".

## Step 4 — Append, don't clobber

Default to **appending** to `pipeline/queue.md`. The user will come back to this command as the
project evolves; wiping their queue loses work that is mid-flight or already reported.

Replace the whole file only if the user explicitly says to start over — and say so when you do.

Never touch an item that already has `pipeline/reports/<id>.md`.

## Step 5 — Report back

Print a compact table: id, type, layer, title, criterion count. Then state:

- How many items, and your rough estimate of one pipeline run each
- Which item must run first and why, if the order carries a dependency
- Anything in the PRD you deliberately **did not** queue, and why — scope you dropped is the
  thing most likely to be missed

Then stop. Running the pipeline is the user's call: `claude --agent orchestrator`.

## Worked example — a PRD sliced small

A PRD for "a bookmark manager with tags, search and a web UI" becomes six items, not one:

```
G-001  greenfield backend   store + POST/GET /bookmarks, JSON file persistence   5 criteria
F-002  feature    backend   DELETE /bookmarks/:id with 204/404                    3 criteria
F-003  feature    backend   tags on bookmarks, normalised, filter by tag          5 criteria
F-004  feature    backend   search across title/url/tags with ranking             5 criteria
F-005  feature    fullstack  web UI: list, add, delete                            5 criteria
F-006  feature    fullstack  tag chips and search box in the UI                   4 criteria
```

Each is an hour and leaves a working app. The one-item version of this is five hours, produces a
41 KB plan, and shows you nothing until it is finished.
