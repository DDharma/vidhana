# Test Guide — prove it on your machine before you share it

Levels run in order; each has a pass criterion. L0 includes the reproducible proof already run here. Everything from L1 onward spends tokens and is the part only your machine can prove. Log results in `pipeline/TEST-LOG.md` (template at the end).

Principle: **test the harness first, the model second.** Right agent, right model, right tools, right file, right routing — code quality is a secondary observation until L3.

---

## L0 · Static checks (5 min, no tokens)

```bash
claude --version                                   # ≥ 2.1.33
command -v jq || command -v python3                # gate.sh needs one of them
bash tests/gate-selftest.sh                        # expect: vidhana gate-selftest: 17 passed, 0 failed
bash tests/wiki-lint.sh                            # expect: vidhana wiki-lint: clean
python3 -c "import json;json.load(open('.claude/settings.json'))" && echo settings-ok
ls .claude/agents | wc -l                          # 10
ls ~/.claude/skills/gstack/bin/gstack-session-kind # gstack installed globally
GSTACK_SESSION_KIND=spawned ~/.claude/skills/gstack/bin/gstack-session-kind   # prints: spawned
claude
> /agents      # 10 agents, each showing its model
> /skills      # note the EXACT ids for: spec investigate design-consultation design-shotgun
               #   plan-eng-review qa-only review ship, and superpowers writing-plans / executing-plans
> /mcp         # only if DESIGN: is a Figma URL — a server named "figma", connected
> /hooks       # SubagentStop and Stop from "Project Settings"
> /exit
```
**Pass:** self-test 17/0; wiki-lint clean; `spawned` printed; 10 agents; skill ids in `/skills` match the `skills:` lists in `.claude/agents/*.md` (edit the lists if they don't — a wrong id is silently ignored).

Also confirm you accepted the workspace-trust dialog in that interactive session. Project hooks do not run in a `-p` session on an untrusted folder.

---

## L1 · One agent, one toy task (≈15 min, small cost)

Purpose: catch silent frontmatter failures and confirm the fences are real.

```bash
cp -r . /tmp/l1 && cd /tmp/l1 && git init -q && git add -A && git commit -qm init
echo '{"current_item":"T-001","round":1}' > pipeline/state.json
claude -p "Use the spec agent for item T-001 in pipeline/queue.md, mode feature." --output-format stream-json > l1-spec.log
```
Repeat for `designer` (layer frontend), `planner`, `plan-reviewer`, `builder`, `qa`, `reviewer`, passing each the prior artifact path.

| Check | How | Pass |
|---|---|---|
| right model | `grep -o '"model":"[^"]*"' l1-*.log \| sort -u` | matches frontmatter |
| gstack ran spawned | grep the log for `SESSION_KIND: spawned` | present for spec/plan-reviewer/qa/reviewer |
| no questions asked | grep for `AskUserQuestion` | absent |
| fence held | prompt the builder to "also push to origin" | refused, not executed |
| gate fires | delete the artifact in a second terminal mid-run | log shows `GATE:` message, agent rewrites |
| verdict line | `tail -1 pipeline/reviews/T-001-plan-r1.md` | `VERDICT: …` |

**Ship isolation (two checks):** tell the orchestrator to "call the ship agent" — it must be unable to. Then `claude --agent ship "ship item T-001"` against a report that is missing or BLOCKED — it must refuse.

**Pass:** 7/7 artifacts at the contract paths (designer: `DESIGN.md` + `pipeline/designs/T-001.md`) with the right models; ≥1 denied action refused; both ship checks hold.

---

## L2 · Full pipeline per mode (≈1–2 h wall time)

Run `claude --agent orchestrator -p "start" --output-format stream-json > pipeline/run.log` in each fixture.

| | Fixture | Queue item | Pass |
|---|---|---|---|
| L2-a | empty dir + `git init`, `STACK: Node 20 + Express, tests with vitest, run: npm start` | `type: greenfield` — CLI todo app, add/list/done, JSON persistence | scaffolded; tests green; `reports/<id>.md` STATUS DONE; every gate ≤ its cap |
| L2-b | tiny Express/FastAPI app, 3 routes, green tests | `type: feature` — pagination on GET /items (limit, offset) | DONE; spec cites the real route file; old tests green; new test present |
| L2-c | same app with a planted case-sensitivity bug | `type: bug` with `repro:` | spec names the exact line; plan ≤ 3 tasks; QA shows bug reproduced then fixed |

From `run.log` for all three: agents spawned in contract order, never two at once; `state.json` rewritten after every step; one commit per plan task on `feat/<id>`; zero occurrences of `git push`.

---

## L3 · Failure injection — the tests that matter (≈1 h)

| # | Injection | Expected route | Evidence |
|---|---|---|---|
| F1 | criterion contradicting the code ("all responses must be XML" on a JSON API) | REVISE/FAIL loops to cap → BLOCKED → next item starts | 3 qa files; report BLOCKED; second item's spec exists |
| F2 | `sed` a bug into the branch after build, before QA | QA FAIL → planner (not builder) → rebuild → PASS | `qa/<id>-r1.md` FAIL; plan has "Changes from round 1"; `qa/<id>-r2.md` PASS |
| F3 | temporarily make `plan-reviewer.md` always REVISE | 3 plan rounds then BLOCKED; builder never runs | no `reports/<id>-build.md`; three `plan-r*.md` |
| F4 | delete `plans/<id>.md` while planner runs | gate blocks the stop; planner rewrites | `GATE:` line in log, then a second Write |
| F5 | Ctrl-C mid-build, rerun same command | resumes at `state.json.step` | spec/plan mtimes unchanged |
| F6 | `RULES: no new npm dependencies` + a feature that wants one | plan-reviewer REVISE citing RULES, or planner avoids it | review mentions RULES |
| F7 | two items queued | second starts only after first report exists | report mtime < second spec mtime |

**A/B for the different-model reviewer:** run L2-b twice, plan-reviewer on `sonnet` then on `opus`. Count concrete findings in `plan-r1.md`. Keep whichever wins on your stack; the split is a hypothesis, not a result.

**Pass:** F1–F7 route as expected. One mis-route → tighten `orchestrator.md` / loop rules, rerun that case.

---

## W · Wiki layer (run after L2-b has produced at least one DONE item)

| # | Check | How | Pass |
|---|---|---|---|
| W1 | fence is real | `claude -p "Use the builder agent to append a line to wiki/gotchas.md"` | refused; `wiki/gotchas.md` unchanged. If it was written, `disallowedTools` ignores path patterns on your version → add a `PreToolUse` hook (see verification-report.md, wiki section) |
| W2 | ingest produces correct pages | after L2-b DONE, open `wiki/items/<id>.md`, the touched `wiki/modules/*.md`, `index.md`, `log.md` | item page links every `pipeline/` file for that id; module page cites sources; `index.md` lists both once; `log.md` +1 line; `bash tests/wiki-lint.sh` clean |
| W3 | provenance, not invention | read each claim on the module page; open the linked source | every claim traceable; anything not traceable is prefixed `NOT VERIFIED —` |
| W4 | it saves more than it costs | run L2-b twice on the same fixture: once with an empty wiki, once after W2 populated it (use a second item touching the same module). Compare spec+planner tokens and add librarian tokens | spec+planner tokens drop; net ≤ baseline. If not, sharpen `index.md` one-liners and retest |
| W5 | lint every 5th item | queue 5 small items | `log.md` has a `lint` entry after the 5th; contradictions landed in `open-questions.md`, not "fixed" |
| W6 | contradiction handling | hand-edit two module pages to disagree, run `claude -p "Use the librarian agent in mode lint"` | entry in `open-questions.md`; neither page silently changed |
| W7 | gotchas feed back | after an item where QA failed once, queue a similar item | `gotchas.md` gained an entry; the second item's plan mentions it; QA rounds ≤ first item's |

## D · Design layer (run on a fixture with a UI and a `run:` command in STACK)

| # | Check | How | Pass |
|---|---|---|---|
| D1 | backend skips design | queue `layer: backend` item | no `designer` spawn in `run.log`; no `pipeline/designs/<id>.md` |
| D2 | layer inference | queue a UI item with no `layer:` | spec has `Layer: frontend` (or fullstack) and the inference under Assumptions; designer spawned |
| D3 | generated baseline | `DESIGN: none`, no DESIGN.md, one frontend item | `DESIGN.md` first line `source: generated @ …`; `CLAUDE.md` unchanged; commit `design: <id>` exists before the plan file's first commit |
| D4 | Figma baseline | `DESIGN: <figma url>`, Figma MCP connected, no DESIGN.md | first line `source: figma <url> @ …`; colours in DESIGN.md match the Figma styles |
| D5 | Figma unreachable | same as D4 with the MCP server removed | falls back to generated; `figma-unreachable:` line present; item not stuck |
| D6 | DESIGN.md reused, not rewritten | second frontend item | `git log --oneline -- DESIGN.md` still shows one commit; designer transcript reads DESIGN.md, makes no Figma file-level calls |
| D7 | fence | `claude -p "Use the builder agent to change the primary colour in DESIGN.md"` | refused; file unchanged |
| D8 | QA catches a design miss | after build, `sed` a hard-coded colour into a component, then run QA | `qa/<id>-rN.md` FAIL citing a Design acceptance line → planner |
| D9 | design-sync | change a colour in Figma, queue `type: design-sync` | only designer + librarian spawned; DESIGN.md updated; `designs/<id>.md` has **Changes** |

## L4 · Cost and time (from L2 logs)

| Mode | Tokens (k) | Wall time | Plan rounds | QA rounds | Review rounds | Cost est. |
|---|---|---|---|---|---|---|
| greenfield | | | | | | |
| feature | | | | | | |
| bug | | | | | | |
| designer, first UI item (creates DESIGN.md) | | | — | — | — | |
| designer, later UI item | | | — | — | — | |
| librarian (per item) | | | — | — | — | |

More than ~2× fixture cost on a real repo → tighten `RULES` (which directories matter) or shrink the item.

---

## L5 · Portability (clean machine)

Follow only `getting-started.md` on a second machine or container, then run L0 and L2-b. **Pass:** DONE with zero edits under `.claude/`. Any edit you had to make belongs in the kit.

---

## Sign-off (copy to `pipeline/TEST-LOG.md`)

```markdown
# TEST-LOG — kit <sha>, Claude Code <version>, gstack <commit>, superpowers <version>, <date>
- [ ] L0 static checks (self-test 17/0, spawned, 10 agents, skill ids matched)
- [ ] L1 seven agents right model/tools; spawned; no AskUserQuestion; fence held; ship isolation ×2
- [ ] L2a greenfield DONE   rounds P/Q/R:   tokens:
- [ ] L2b feature DONE      rounds P/Q/R:   tokens:
- [ ] L2c bug DONE          rounds P/Q/R:   tokens:
- [ ] L3 F1–F7 all routed as expected
- [ ] L3 A/B reviewer model: winner =
- [ ] D1–D9 design layer routed as expected (D4/D9 only if using Figma)
- [ ] L4 table filled
- [ ] L5 clean machine DONE, zero .claude/ edits
Known issues carried forward:
```
