# Getting Started — Vidhana

From zip to first automated feature in about 20 minutes of setup plus one wait. You don't need to understand the internals; `docs/build-guide.md` has them if you want them.

## What it does

You describe a feature or bug in a text file and run one command. AI agents write a spec, plan it, review the plan, build it test-first on a new branch, run QA, review the code, and write you a report. It never pushes, merges, or ships — shipping is a separate command you run after reading the report. It never asks you anything mid-run; if it can't get a step right after a few tries it marks the item `BLOCKED` and moves on.

## 1 · Prerequisites

```bash
claude --version        # 2.1.33 or higher  (https://docs.claude.com/en/docs/claude-code/overview)
git --version
jq --version || python3 --version   # one of the two; the safety gate needs it
```
Plus the toolchain your project uses (node/python/etc.) and an active Claude subscription or API key on this machine. The pipeline is 7 Claude sessions per item — read **Cost** below before pointing it at anything large.

## 2 · Install the two skill libraries (once per machine)

```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup

claude
> /plugin install superpowers@claude-plugins-official
> /exit
```
gstack goes in your home folder, not in the project — that is its supported install; a copy inside the repo is deprecated by its author and won't work.

## 3 · Unzip into your project

```bash
cd /path/to/your-project     # for a brand-new project: mkdir it, cd, git init
git clone https://github.com/<you>/vidhana.git tmp-kit && cp -r tmp-kit/. . && rm -rf tmp-kit/.git tmp-kit   # or unzip the release
chmod +x .claude/hooks/*.sh tests/*.sh
bash tests/gate-selftest.sh                  # expect "vidhana gate-selftest: 13 passed, 0 failed"
bash tests/wiki-lint.sh                      # expect "vidhana wiki-lint: clean"
```
It must sit at the repo root, next to `.git`.

## 4 · Trust the folder and verify

```bash
claude            # accept the "trust this folder" dialog — the safety hooks do not run until you do
> /agents         # 9 agents: orchestrator spec planner plan-reviewer builder qa reviewer librarian ship
> /skills         # look for: spec, investigate, plan-eng-review, qa-only, review, ship,
                  #           and the superpowers writing-plans / executing-plans entries
> /exit
```
Agents missing → you unzipped in the wrong folder. Skills missing → redo step 2.
If the superpowers skills show a different id than `superpowers:writing-plans`, open `.claude/agents/planner.md` and `builder.md` and paste the id you see.

## 5 · Tell it about your project — three lines

Edit only the top of `CLAUDE.md`; everything under `# VIDHANA PIPELINE CONTRACT` stays as is.

```markdown
NAME: Acme Billing API
STACK: Python 3.11 + FastAPI + Postgres; test: pytest -q; run: uvicorn app.main:app --port 8000
RULES: no new dependencies without a reason in the plan; /v1 endpoints stay backward compatible; conventional commits
```
Put the **exact** test command and run command in `STACK`. Most bad first runs come from the agents guessing these. `RULES` is your leash — the plan reviewer enforces it.

## 6 · First run — start with a throwaway

`pipeline/queue.md` already contains a harmless sample item (`GET /health`). Keep it for the first run so you see the shape of the output. Adjust the title if your project isn't an HTTP service.

```bash
claude --agent orchestrator
```
It starts on its own. A small item takes roughly 10–25 minutes.

### The three item types

| `type:` | When | Write |
|---|---|---|
| `greenfield` | empty repo | describe the whole small app |
| `feature` | normal | title + testable acceptance criteria |
| `bug` | something is broken | a `repro:` line with exact steps, actual vs expected |

Queue several; they run one at a time, top to bottom.

## 7 · Read the report

`pipeline/reports/<id>.md` says `STATUS: DONE` (work on branch `feat/<id>`, committed, not pushed) or `STATUS: BLOCKED` (retry limit hit; branch has what it managed; report says which gate failed).

The first few times, also open `pipeline/specs/<id>.md` and read **Assumptions** — the agents never ask questions, so that's where a misunderstanding shows up before it costs anything.

## 7b · The wiki (project memory)

After each item a `librarian` agent writes what was learned into `wiki/`: a page per item, a page per module it touched, decisions, and a `gotchas.md` of things QA and review keep catching. The next item's spec and planner read `wiki/index.md` first, so they stop re-reading the whole repo. You never write `wiki/` yourself; open it in any markdown viewer (Obsidian renders the `[[links]]` and a graph) and read `wiki/overview.md`, `wiki/gotchas.md`, and `wiki/items/<id>.md`. `bash tests/wiki-lint.sh` tells you if the structure is healthy. Details: `docs/wiki-usage.md`.

## 8 · Review and ship

```bash
git diff main..feat/<id>
claude --agent ship "ship item <id>"     # refuses unless the report says DONE
```
The pipeline itself cannot call `ship`; only you can.

## Troubleshooting

| Symptom | Fix |
|---|---|
| stopped or Ctrl-C'd | rerun `claude --agent orchestrator` — it resumes from `pipeline/state.json` |
| every item BLOCKED | your `STACK` test/run command is wrong — run it by hand |
| QA fails on unrelated things | your suite was already red; get `main` green first |
| agents asking questions | you ran plain `claude`; use `claude --agent orchestrator`. Also check `GSTACK_SESSION_KIND` is in `.claude/settings.json` |
| "hook error" / hooks not firing | folder not trusted (step 4), or `chmod +x` skipped (step 3) |
| start fresh | `echo '{}' > pipeline/state.json` and clear `pipeline/{specs,plans,reviews,qa,reports}`; to also forget the wiki, restore `wiki/` from the zip |
| `wiki-lint` fails after a run | read the `LINT:` lines; run `claude -p "Use the librarian agent in mode lint"`; if it persists, the librarian prompt needs tightening |

## Cost, honestly

Six or seven Claude sessions per item, each reading your repo; retry loops multiply it. Keep items to one afternoon of human work, write acceptance criteria you could check by hand, and watch the first runs. If it keeps re-reading the whole repo, add a `RULES` line saying which directories matter.

## It will not

push, merge, or delete branches · touch `.claude/` or `queue.md` · ask your opinion mid-run · judge whether the idea was worth building. That last part stays yours; that's why you read the report before shipping.

---
*Something odd? Send `pipeline/reports/<id>.md` and `pipeline/run.log`.*
