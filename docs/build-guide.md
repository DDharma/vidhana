# Build Guide — Autonomous Feature Pipeline (Option B, no human gates)

The kit *is* this repository: clone it into a project and the `.claude/`, `pipeline/`, `wiki/`, and `tests/` folders are the kit. This guide explains what each file does and why, so you can maintain it. For proof of each claim see `verification-report.md`; for how to prove the parts only your machine can prove, see `test-guide.md`.

## 1. What runs, in one paragraph

You launch one Claude Code session as the `orchestrator` agent. It reads `pipeline/queue.md`, picks the next item, and spawns purpose-built subagents in sequence: `spec → [designer] → planner → plan-reviewer → builder → qa → reviewer`. The designer runs only when the item's layer is `frontend` or `fullstack` (§5c). Each subagent is a Markdown file in `.claude/agents/` that pins a model, a tool allowlist, and the skills it preloads (gstack for spec/review/QA, Superpowers for planning/execution). Each must write a specific artifact before Claude Code lets it finish — a `SubagentStop` hook (`gate.sh`) blocks it otherwise. The orchestrator reads the artifact's `VERDICT:` line and loops or advances per fixed rules with round caps. A `ship` agent exists, but the orchestrator's tool list physically excludes it.

## 2. Folder tree (as shipped in the repository root)

```
<repo root>
├── CLAUDE.md                     4 editable lines + the PIPELINE CONTRACT + DESIGN and WIKI schemas
├── README.md                     6-command summary for recipients
├── DESIGN.md                     (not shipped) project design system, written by the designer on the first UI item
├── .claude/
│   ├── settings.json             env (GSTACK_SESSION_KIND=spawned), allow/deny, hooks
│   ├── rules/wiki-conventions.md the wiki schema: 6 rules + page templates
│   ├── agents/                   orchestrator spec designer planner plan-reviewer builder qa reviewer librarian ship
│   └── hooks/
│       ├── gate.sh               SubagentStop: no artifact / no VERDICT → exit 2 → cannot stop
│       └── sync-reports.sh       Stop: copy pipeline/ to a bucket if PIPELINE_BUCKET is set
├── pipeline/                     RAW SOURCES — written once, never edited
│   ├── queue.md                  work items (one sample item included)
│   ├── state.json                orchestrator checkpoint, starts as {}
│   └── specs/ designs/ plans/ reviews/ qa/ reports/
├── wiki/                         PROJECT MEMORY — librarian writes, spec/planner read
│   ├── index.md log.md overview.md gotchas.md open-questions.md
│   └── modules/ decisions/ items/
└── tests/
    ├── gate-selftest.sh          reproduces the 17-case gate proof
    └── wiki-lint.sh              deterministic wiki checks, no model call
```

Not in the kit, installed per machine: gstack (global) and the Superpowers plugin. See §4. `scripts/bootstrap.sh` does both and is what cloud sessions run.

## 3. The four mechanisms that make it unattended

| Mechanism | Where | Why it matters |
|---|---|---|
| `GSTACK_SESSION_KIND=spawned` | `settings.json → env` | gstack skills contain interactive decision points. In spawned mode they auto-choose the recommended option and never call `AskUserQuestion` (source: every gstack SKILL.md, "AskUserQuestion Format" §1; `bin/gstack-session-kind`). Without this line the pipeline stalls at the first `/spec` question. |
| Round caps in `CLAUDE.md` | Loop rules | Replace the human "send it back" decision. Plan 3 / QA 3 / Review 2, then `STATUS: BLOCKED` and move on. |
| `gate.sh` on `SubagentStop` | `settings.json → hooks` | An agent cannot declare itself done without its artifact and (for reviewers/QA) a `VERDICT:` line. Enforced by Claude Code via exit code 2, not by the prompt. |
| `permissions.deny` | `settings.json` | `git push`, `git merge`, `rm -rf`, editing `.claude/` or `queue.md` are refused at the harness level regardless of what any agent decides. |

## 4. Installing the two skill libraries (per machine)

```bash
# gstack — global install is the only supported path (its --local mode prints a deprecation warning)
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup

# Superpowers — plugin
claude
> /plugin install superpowers@claude-plugins-official
> /skills        # confirm the exact ids; adjust the skills: lists in .claude/agents/ if they differ
```

To make a repo *require* gstack for teammates (gstack's own team mode), run once from the repo root:
```bash
(cd ~/.claude/skills/gstack && ./setup --team) && ~/.claude/skills/gstack/bin/gstack-team-init required
```
This writes a SessionStart check into `.claude/settings.json` (merging with the kit's hooks) and a `## gstack` block into `CLAUDE.md`. Commit both.

## 5. Agent design

| Agent | Model | Skills preloaded | Writes | Notes |
|---|---|---|---|---|
| orchestrator | sonnet | — | `state.json`, `reports/<id>.md`, commits | `tools:` lists `Agent(spec) … Agent(librarian)`; **no** `Agent(ship)`; routes by layer |
| spec | opus | `spec`, `investigate` | `specs/<id>.md` | bug items use `/investigate`; writes a `Layer:` line; must end with "Acceptance criteria" |
| designer | opus | `design-consultation`, `design-shotgun` | `DESIGN.md` (if missing / design-sync) + `designs/<id>.md` | frontend/fullstack only; no `tools:` line so Figma MCP tools are inherited; gate: both files must exist |
| planner | opus | `superpowers:writing-plans` | `plans/<id>.md` | opens with "Changes from round N" when looping |
| plan-reviewer | sonnet | `plan-eng-review` | `reviews/<id>-plan-rN.md` | last line `VERDICT: APPROVE\|REVISE` |
| builder | sonnet | `superpowers:executing-plans` | branch `feat/<id>` + `reports/<id>-build.md` | `disallowedTools` blocks push/merge/reset |
| qa | sonnet | `qa-only` | `qa/<id>-rN.md` | no `Edit`; report-only QA |
| reviewer | opus | `review` | `reviews/<id>-code-rN.md` | last line `VERDICT: APPROVE\|REVISE` |
| librarian | sonnet | — (follows `.claude/rules/wiki-conventions.md`) | `wiki/**` | runs after every DONE/BLOCKED; `lint` every 5th item; gate: `log.md` must grow |
| ship | sonnet | `ship` | — | manual: `claude --agent ship "ship item <id>"`; refuses unless report says DONE |

Model choice is a judgment: opus where a mistake is expensive (spec, design, plan, final review), sonnet where the work is mechanical or long (build, QA, routing). The planner/plan-reviewer split across models is a hypothesis; the Test Guide has an A/B step to measure it on your stack.

Pin full model IDs (e.g. `claude-opus-5`) instead of aliases once you have a working baseline, so results don't drift when aliases move.

## 5b. The wiki layer (project memory)

Karpathy's LLM-wiki pattern applied to the pipeline's own paperwork. `pipeline/` is the immutable raw-source layer; `wiki/` is the LLM-maintained layer; `CLAUDE.md § WIKI SCHEMA` + `.claude/rules/wiki-conventions.md` is the schema layer. After each item the `librarian` compiles that item's spec/plan/reviews/QA into `wiki/items/<id>.md`, updates the touched `wiki/modules/` pages, records real decisions, adds recurring findings to `gotchas.md`, rebuilds `index.md`, appends to `log.md`. Spec and planner read `index.md` first and at most four pages before touching source — that is where the token saving comes from.

Fences: only the librarian lacks `disallowedTools: Write(./wiki/**), Edit(./wiki/**)`; the gate refuses to let the librarian stop unless `log.md` grew; `tests/wiki-lint.sh` fails on broken links, un-indexed pages, orphans, bare SHAs or "the N modules" phrases in prose, and malformed log headings. Full design: `wiki-structure.md`. How to use it well: `wiki-usage.md`.

## 5c. The design layer

Design sits **after spec and before the planner**, not after plan review: the planner splits work into tasks that each name a test, and for UI work those tasks depend on which screens, states and tokens exist. Designing after an approved plan would force a replan and waste a plan round.

Two levels:

| Level | File | Written | Content |
|---|---|---|---|
| System | `DESIGN.md` at repo root | once, by the designer, when missing; again only for a `type: design-sync` item | colour tokens and rules, typography, spacing, radii/elevation/motion, components, do/don't. First line `source: figma <url> @ <date>` or `source: generated @ <date>` |
| Item | `pipeline/designs/<id>.md` | every frontend/fullstack item | screens, states, token names used, token gaps, **Design acceptance** checkboxes |

Where DESIGN.md comes from is set by the `DESIGN:` line in `CLAUDE.md`. A Figma URL means the designer reads styles, variables and components through the Figma MCP; `none` (or Figma unreachable) means gstack `/design-consultation` generates a baseline. gstack's `design-review`, `plan-design-review`, `design-shotgun` and `design-html` all read a root `DESIGN.md` natively, so the file serves them too. After that, planner, plan-reviewer, builder, QA and reviewer read `DESIGN.md` and `designs/<id>.md` — nobody goes back to Figma per item.

Routing: the orchestrator takes the layer from the item's `layer:`, else the spec's `Layer:` line, else `fullstack` (design runs when in doubt). Right after the designer returns, the orchestrator commits `DESIGN.md` and `pipeline/designs/` on the current branch, so the builder's `feat/<id>` branch and every later item contain the same design system.

Fences: every other agent has `Write/Edit(./DESIGN.md)` in `disallowedTools`; the designer cannot commit or edit `CLAUDE.md` (gstack's `/design-consultation` otherwise offers to add a design section there). QA checks "Design acceptance" lines report-only; it deliberately does not preload `/design-review`, which fixes code. Figma MCP: add it as a server named `figma` (the settings allow `mcp__figma`) and authenticate it on the machine beforehand — OAuth cannot happen inside a `-p` or CI run. Without it the designer falls back to a generated DESIGN.md and records `figma-unreachable:`.

## 6. Data contract

```markdown
## item: F-001                    # id → all artifact names
type: feature                     # greenfield | feature | bug | design-sync
layer: frontend                   # optional: backend | frontend | fullstack (spec infers if absent)
design: https://figma.com/...     # optional: frames for this item's screens
title: ...
acceptance:                       # feature/greenfield: testable criteria
- ...
repro: ...                        # bug only: exact steps, actual vs expected
```
`state.json` (written by the orchestrator): `{current_item, step, layer, round, rounds:{plan,qa,review}, started}`. `gate.sh` reads `current_item` and `round` from it to know which file to demand.

## 7. Running

```bash
claude                          # once per repo: accept the workspace-trust dialog, then /exit
                                # (project hooks do not run until trusted; -p does not count)
claude --agent orchestrator     # interactive; initialPrompt fires automatically
# or unattended with a log:
claude --agent orchestrator -p "start" --max-turns 400 --output-format stream-json > pipeline/run.log
```
Re-running the same command after a crash resumes from `state.json`.

## 8. The three project situations

| Situation | What changes |
|---|---|
| New project from scratch | `git init`; first item `type: greenfield`; `STACK` line decides scaffold |
| Existing running project | unzip at repo root; fill `STACK`/`RULES` from the real repo; get `main` green first |
| Bug fix from current state | item `type: bug` with `repro:`; spec step becomes `/investigate`; plans are usually 1–3 tasks |
| UI work | set `DESIGN:` in `CLAUDE.md` (Figma URL or `none`); first frontend/fullstack item creates `DESIGN.md`; `type: design-sync` refreshes it after Figma changes |

Modes and layers are per item, so a mixed queue is fine.

## 9. Running in the cloud for maximum throughput

Everything above assumes a laptop. The kit is designed so the same files run unattended in three cloud shapes. What is verified: the kit's configuration is all repo-local (hooks, agents, env, permissions live in `.claude/`), which is the requirement stated in the Claude Code hooks reference for cloud sessions — they read settings and hooks from the repo, not from `~/.claude/`. What is not verified here: any specific provider's runtime; treat each recipe as a template and run Test Guide L0 in that environment first.

### 9.1 The one thing every cloud shape needs: bootstrap

gstack is a global install and Superpowers is a plugin, so a fresh cloud machine has neither. `scripts/bootstrap.sh` installs both idempotently. Wire it in one of two ways:

- **SessionStart hook** (already configured in `settings.json`): runs the script if `~/.claude/skills/gstack` is missing. First session pays ~1 minute; later sessions skip.
- **Image or environment setup**: run `bash scripts/bootstrap.sh` once when building the container or configuring the environment's setup script. Preferred for CI, where session start time matters.

### 9.2 Shape A — Claude Code on the web

Push the repo, open it as a cloud session, and run `claude --agent orchestrator` from there. Hooks and agents load from the repo. The `GSTACK_SESSION_KIND=spawned` env comes from `settings.json`, so it applies. Long items suit this shape because the session survives your laptop closing. Limitation to check: the workspace-trust rule — accept trust in the web session once before relying on hooks.

### 9.3 Shape B — a container or VM you control (best throughput)

```bash
docker run -it --rm -e ANTHROPIC_API_KEY -v "$PWD:/work" -w /work node:20 bash -c '
  npm i -g @anthropic-ai/claude-code && apt-get update -qq && apt-get install -y -qq git jq &&
  bash scripts/bootstrap.sh && claude --agent orchestrator -p "start" --max-turns 400 --output-format stream-json > pipeline/run.log'
```

**Parallelism is where the performance comes from.** Items in the queue are independent, and each runs on its own `feat/<id>` branch. Run N containers, each with a queue holding one item and a `PIPELINE_BUCKET` pointing at the same bucket. Do not run two orchestrators on the same checkout: `state.json` is a single file. The rule is one checkout per orchestrator, which is what containers give you for free. Merge conflicts between branches are handled at `/ship` time, by a human, one branch at a time — the same as today. If `DESIGN.md` does not exist yet, run one `type: design-sync` item and commit its `DESIGN.md` **before** fanning out; otherwise each container generates its own, different design system.

Cost note: N parallel runs cost N× the tokens in a fraction of the wall time; the per-item cost doesn't change. Set `--max-turns` and consider a per-container budget using your provider's spend limits, because a looping item is capped in rounds but not in turns per round.

### 9.4 Shape C — CI on a schedule or on queue change

`.github/workflows/pipeline.yml` is a template that runs the orchestrator when `pipeline/queue.md` changes on a `pipeline/*` branch, then pushes the resulting `feat/*` branch and commits the wiki. Read it before enabling: it needs `ANTHROPIC_API_KEY` as a repository secret, and the push step is the only place in the whole kit where anything pushes — it pushes the feature branch for review, never to main. If your policy is "nothing pushes without a human", delete that step and download `pipeline/` as an artifact instead.

### 9.5 Settings that matter for unattended cloud runs

| Setting | Where | Why |
|---|---|---|
| `GSTACK_SESSION_KIND=spawned` | `settings.json env` | gstack skills never wait for input |
| `--max-turns 400` | launch command | hard stop even if the loop rules fail |
| `permissionMode: acceptEdits` on orchestrator; `Bash` allowlist in `settings.json` | already set | no permission prompts, no hang |
| `PIPELINE_BUCKET` | container env | reports and wiki survive the container |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000` | `settings.json env` | long plan/QA files aren't truncated |
| small `CLAUDE.md`, sharp `wiki/index.md` | repo | the biggest lever on tokens per item; see wiki-usage.md §4 |

### 9.6 What not to do in the cloud

- Don't set `permissionMode: bypassPermissions` to "make it faster". The deny list is what keeps an unattended run from pushing or deleting; bypass removes it.
- Don't share one checkout between parallel orchestrators.
- Don't skip bootstrap and hope: without gstack the spec agent fails its first skill call, the gate blocks it forever, and you burn 60 turns finding out.

## 10. Own harness (phase 2, only if needed)

Move the loop into code with the Claude Agent SDK when testing shows the orchestrator mis-routing more than ~1 in 10 runs, or when you need routing logic frontmatter can't express (e.g. "opus only if the diff exceeds 500 lines"), audit logging, or hard cost caps. Your script owns the state machine and calls `query()` once per step with the same agent definitions; the model never decides what step comes next. Everything in the repository root carries over; only `orchestrator.md` is replaced by ~150 lines of code. Do not start there.

## 11. Known limits

- **Cost**: 6–10 fresh contexts per item, each reading the repo. Measure on a fixture first (Test Guide L4).
- **`qa-only` needs a way to exercise the app**: put the exact run command in `STACK`; with no UI it falls back to test-suite evidence.
- **The gate checks presence, not honesty**: an agent could write `VERDICT: PASS` on a lie. Test Guide L3 F2 (planted bug) is how you check QA actually says FAIL when it should.
- **`skills:` preload ids**: confirm against `/skills` output; a misspelled id is silently ignored.
- **The wiki lint proves shape, not truth.** A page can be well-linked and wrong. Read the first three `wiki/items/` pages yourself (Test Guide W2).
- **DESIGN.md is a copy, not a live link.** Figma changes do not reach the pipeline until a `type: design-sync` item runs; the `source: … @ date` line shows how old the copy is.
- **Branches stack.** Each `feat/<id>` is created from whatever branch is checked out, so later items (and the committed `DESIGN.md`) build on earlier unshipped branches. Ship in queue order.
- **Worktree isolation** is intentionally off in v1. If you re-enable `isolation: worktree` on the builder, artifacts are written inside the worktree branch — read them with `git show feat/<id>:pipeline/...`.
