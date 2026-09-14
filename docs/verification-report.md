# Verification Report — what is proven, what is not

Date: 2026-09-13 (updated same day with the LLM-wiki layer). Everything marked **PROVEN** was executed or read from source today; the command that proves it is shown so you can re-run it. Everything marked **YOUR MACHINE** cannot be proven without Claude Code credentials and a real repo, and the Test Guide tells you exactly how to prove it yourself.

## Straight answers

**Does it work?** The parts are real and current. gstack (garrytan, commit `71f6048`, 9 Sep 2026) and Superpowers (obra, v6.3.0, commit `b36e082`) both exist, both contain every skill the pipeline references, and gstack has a built-in *spawned session* mode that removes every human prompt — which is the exact behaviour your no-human design needs. The Claude Code features used (custom subagents with pinned models, `skills:` preload, `SubagentStop` hooks with exit-2 blocking, permission deny rules) are in the current official docs. The gate script is unit-tested. What is **not** proven is the end-to-end run, because that needs your credentials and a repo; the Test Guide's L2/L3 exists for that, and a first pass takes about half a day.

**Can it be used for better coding?** The honest version: the two skill libraries enforce plan-before-code, test-first, and review-before-done. That structure is what most teams find reduces rework, and the Superpowers README claims multi-hour unattended runs that stay on plan. I have no controlled study showing the pipeline produces measurably better code than a single careful session, and I will not pretend to. What the kit *provably* gives you is (a) hard fences that a single session doesn't have — no push, no merge, no finishing without an artifact and a verdict — and (b) a paper trail per feature. Whether that translates to better code on *your* stack is what the L4 cost table and the plan-reviewer A/B test in the Test Guide measure.

## Evidence table

| # | Claim in the docs | Status | Proof |
|---|---|---|---|
| 1 | gstack has skills `spec`, `investigate`, `plan-eng-review`, `qa`, `qa-only`, `review`, `ship` | **PROVEN** | `git clone --depth 1 https://github.com/garrytan/gstack && ls gstack/*/SKILL.md` — all 7 present among 55 skills |
| 2 | Superpowers has skills `writing-plans`, `executing-plans` | **PROVEN** | `git clone --depth 1 https://github.com/obra/superpowers && ls superpowers/skills/` — present; plugin name `superpowers` in `.claude-plugin/plugin.json` |
| 3 | gstack skills can run with zero human prompts | **PROVEN** | `gstack/bin/gstack-session-kind` returns `spawned` when `GSTACK_SESSION_KIND=spawned`; every SKILL.md's *AskUserQuestion Format* section says a spawned session must "auto-choose the recommended option at every decision point … never prose, never BLOCKED", except destructive choices, which fall to the conservative option. The kit sets this env in `.claude/settings.json`. |
| 4 | gstack skills are **not** namespaced `gstack:` | **PROVEN** | gstack ships no `.claude-plugin/` manifest; skill frontmatter is `name: spec`, `name: qa-only`, etc. My first draft had this wrong — fixed in all agent files. |
| 5 | Vendoring gstack into the repo is the wrong distribution method | **PROVEN** | `gstack/setup --local` prints "Warning: --local is deprecated. Use global install + --team instead." and `bin/gstack-team-init` actively removes a vendored copy and gitignores it. Skill files also hard-code `~/.claude/skills/gstack/...` paths (15 occurrences in `spec/SKILL.md`). First draft had this wrong — fixed. |
| 6 | Subagent frontmatter supports `model`, `tools`, `disallowedTools`, `skills`, `maxTurns`, `permissionMode`, `memory`, `hooks`, `isolation`, `initialPrompt` | **PROVEN (docs)** | Field table mirrored from official `code.claude.com/docs/en/sub-agents` (v2.1.160 snapshot). Note: "misspelled frontmatter fields silently fail" — hence Test Guide L1. |
| 7 | `SubagentStop` hook input includes `agent_type`; exit code 2 prevents the subagent from stopping | **PROVEN (official)** | `code.claude.com/docs/en/hooks`, fetched today: "`agent_type` … Present when … the hook fires inside a subagent"; table row `SubagentStop — Can block? Yes — Prevents the subagent from stopping`. Also: "exit code 2 is the only exit code that blocks through the code alone." |
| 8 | Inside a worktree, `cwd` moves but `${CLAUDE_PROJECT_DIR}` stays on the main checkout | **PROVEN (official)** | Same page, note titled "Worktrees are different". First draft's gate script would have looked in the wrong tree — fixed to use `CLAUDE_PROJECT_DIR`, and `isolation: worktree` removed from the builder for v1. |
| 9 | Project hooks only run after workspace trust is accepted; a `-p` run does not count | **PROVEN (official)** | Same page: "A `-p` session doesn't count as accepting it." Getting Started now says to open `claude` interactively once and accept trust. |
| 10 | `gate.sh` blocks a subagent that has no artifact or no VERDICT line, allows otherwise, works from a worktree, works without `jq` | **PROVEN (executed)** | `bash tests/gate-selftest.sh` → 10 passed, 0 failed. Bug found and fixed during testing: the first version was *fail-open* when `jq` was absent. It now falls back to `python3` and fails closed. |
| 11 | `settings.json` is valid; all 8 agent files have valid YAML frontmatter; orchestrator cannot spawn `ship` | **PROVEN (executed)** | `python3 -c "import json;json.load(open('.claude/settings.json'))"`; PyYAML parse of each agent; `grep -c 'Agent(ship)' orchestrator.md` → 0 |
| 12 | The Mermaid diagram renders | **PROVEN (executed)** | `mermaid.parse()` via mermaid@latest + jsdom → `flowchart-v2`, no errors |
| 13 | Declaring plugins in project `settings.json` auto-installs them for teammates | **DISPROVEN** | anthropics/claude-code issues #32606, #45323, #25613: declared plugins register but do not install; show as "failed to load". Getting Started therefore requires the one-line manual install. |
| 14 | The orchestrator follows the loop rules, counts rounds correctly, and emits BLOCKED at the limit | **YOUR MACHINE** | Test Guide L3 F1–F7 |
| 15 | Cost per item and wall time | **YOUR MACHINE** | Test Guide L4 |
| 16 | A different model as plan-reviewer catches more than the same model | **UNPROVEN, measurable** | Test Guide L3 A/B step. This is a judgment, not a result. |
| 17 | Gate blocks the librarian unless `wiki/log.md` gained an entry (ingest and lint modes) | **PROVEN (executed)** | `bash tests/gate-selftest.sh` → 13 passed, 0 failed (3 librarian cases added) |
| 18 | `tests/wiki-lint.sh` catches broken links, un-indexed pages, orphans, bare SHAs, copied counts, malformed log headings; and is clean on the skeleton | **PROVEN (executed)** | 6 planted defects each produced exit 1 with the expected `LINT:` line; skeleton → `wiki-lint: clean`. Two bugs found and fixed during testing: commented-out template links were counted as real links (both in link resolution and orphan detection). |
| 19 | Only the librarian can write `wiki/`; every other agent (including orchestrator) has `Write/Edit(./wiki/**)` in `disallowedTools` | **PROVEN (static)** | PyYAML parse of all 9 agent files; librarian is the only one without the fence. Whether `disallowedTools` honours path patterns on your Claude Code version is Test Guide W1. |
| 20 | Spec and planner are told to read `wiki/index.md` before source | **PROVEN (static)** | first body line of both agent files |
| 21 | The wiki reduces spec/planner tokens by more than the librarian costs | **YOUR MACHINE** | Test Guide W4 (same fixture, wiki on vs off) |
| 22 | The librarian writes accurate pages with correct provenance links | **YOUR MACHINE** | Test Guide W2, W3 — the lint proves structure, not truth |

### Design layer (added 2026-09-14)

| # | Claim in the docs | Status | Proof |
|---|---|---|---|
| 23 | Gate blocks the designer until both `DESIGN.md` and `pipeline/designs/<id>.md` are non-empty | **PROVEN (executed)** | `bash tests/gate-selftest.sh` → 17 passed, 0 failed (4 designer cases added: nothing, item file only, DESIGN.md only, both) |
| 24 | gstack's design skills use a root `DESIGN.md` as the design-system source | **PROVEN (source)** | `grep -n DESIGN.md ~/.claude/skills/gstack/{design-consultation,design-review,plan-design-review,design-shotgun}/SKILL.md` — `design-consultation` writes it; the others read it and calibrate against it |
| 25 | `design-consultation` also offers to write a design section into `CLAUDE.md` | **PROVEN (source)** | `design-consultation/sections/proposal-and-preview.md` Phase 6. The designer is fenced from `CLAUDE.md` and told to decline |
| 26 | All 10 agent files have valid YAML frontmatter; only the designer lacks the `DESIGN.md` fence | **PROVEN (executed)** | `npx js-yaml` on each frontmatter block; `grep -L 'Write(./DESIGN.md)' .claude/agents/*.md` → designer.md, ship.md (ship has no Write tool) |
| 27 | An agent with no `tools:` line inherits MCP tools, so the designer can reach Figma | **PROVEN (docs)** | sub-agents docs: omitting `tools` inherits all tools, including MCP tools. Confirm on your machine with Test Guide D4 |
| 28 | Layer routing, Figma extraction, fallback, reuse and design-sync behave as described | **YOUR MACHINE** | Test Guide D1–D9 |

## Corrections made to the first draft (so you know what changed)

1. Skill names: `gstack:spec` → `spec` (and same for the other five gstack skills).
2. Distribution: vendored `.claude/skills/gstack/` → global install + `gstack-team-init required` (gstack's own supported path).
3. Added `GSTACK_SESSION_KIND=spawned` to `settings.json` — without it, gstack skills would stall waiting for answers.
4. Gate script: fixed fail-open without `jq`; switched to exit-2 blocking; uses `CLAUDE_PROJECT_DIR`.
5. Removed `isolation: worktree` from builder (artifact paths would land in the worktree; re-add later once the pipeline is stable).
6. Added the workspace-trust step to Getting Started.
7. Added the repository root — the actual files, not just their description — plus `tests/gate-selftest.sh` so the proof is reproducible.
8. Added the LLM-wiki layer (Karpathy pattern): `wiki/` skeleton, `librarian` agent, `.claude/rules/wiki-conventions.md`, `tests/wiki-lint.sh`, gate case, orchestrator step 7, wiki fences on all other agents, spec/planner read-index-first. Design in `wiki-structure.md`, usage in `wiki-usage.md`.
9. Added the design layer (2026-09-14): `designer` agent between spec and planner for frontend/fullstack items, `DESIGN.md` system file (Figma via MCP, or generated), `pipeline/designs/<id>.md` per item, `layer:`/`design:` item fields, `type: design-sync`, `DESIGN:` line in `CLAUDE.md`, gate case, `DESIGN.md` fences, QA design-acceptance checks. Stale counts in rows 10, 11, 17, 19 are superseded by rows 23 and 26.

## What I could not check (wiki)

- Whether `disallowedTools: Write(./wiki/**)` is honoured with a path pattern, or only bare tool names. Test Guide W1 checks it. If it fails, the fallback is a `PreToolUse` hook (matcher `Write|Edit`) that exits 2 when the target path is under `wiki/` and the input's `agent_type` is not `librarian` — both fields are in the documented hook input.
- Quality of what the librarian writes. The lint checks shape (links, index, log, no moving values); it cannot check that a claim is true. W2/W3 in the Test Guide are the human read of the first three ingests.

## What I could not check

- Whether Claude Code's `skills:` preload resolves the plugin-namespaced id `superpowers:writing-plans` versus bare `writing-plans`. Run `/skills` after install and match the agent files to what it prints (Test Guide L0).
- Exact behaviour of `initialPrompt` under `--agent` on your Claude Code version.
- gstack's `/qa-only` behaviour when there is no runnable app (it should fall back to test evidence; verify on your fixture).
