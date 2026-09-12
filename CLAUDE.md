# PROJECT  ← edit these three lines per project
NAME: <project name>
STACK: <language + framework; exact test command; exact run command>
RULES: <dependency policy; files never to touch; conventions>

# VIDHANA PIPELINE CONTRACT (do not edit per project)

You are running Vidhana, an unattended engineering pipeline. There is no human in the loop.
Work items live in pipeline/queue.md. Process them one at a time, top to bottom.
Never start the next item until pipeline/reports/<id>.md exists for the current one.

## Modes (from each item's `type:` field)
- greenfield : nothing exists yet → spec includes scaffold, tooling, first runnable test.
- feature    : existing codebase → spec cites the files it will touch.
- bug        : start from current state → spec step runs /investigate (root cause), then continue at Plan.

## Steps and required artifacts (an agent that does not write its artifact has FAILED that round)
1 spec          → pipeline/specs/<id>.md
2 planner       → pipeline/plans/<id>.md
3 plan-reviewer → pipeline/reviews/<id>-plan-r<N>.md    last line: VERDICT: APPROVE | REVISE
4 builder       → branch feat/<id> + pipeline/reports/<id>-build.md
5 qa            → pipeline/qa/<id>-r<N>.md              last line: VERDICT: PASS | FAIL
6 reviewer      → pipeline/reviews/<id>-code-r<N>.md    last line: VERDICT: APPROVE | REVISE
7 librarian     → wiki/items/<id>.md + updated wiki/index.md + one new line in wiki/log.md
                  runs after every DONE or BLOCKED; mode lint every 5th item
8 ship          → NEVER invoked by this pipeline. A human runs `claude --agent ship` separately.

## Loop rules (automated gates)
- plan-reviewer REVISE → planner again with the review path attached.  Max 3 plan rounds.
- qa FAIL              → planner again (not builder) with the QA path attached.  Max 3 QA rounds.
- reviewer REVISE      → builder again with the review path attached.  Max 2 review rounds.
- Any max exceeded     → write pipeline/reports/<id>.md with STATUS: BLOCKED, commit, move on. Never retry.
- No VERDICT line      → treat as the failing verdict for that gate.

## Reporting — pipeline/reports/<id>.md must contain
STATUS (DONE|BLOCKED) · branch · commit list · spec summary · Assumptions copied from the spec ·
rounds used per gate · final QA verdict · final review verdict · open risks · start/finish time.

## WIKI SCHEMA
pipeline/ holds raw sources and is never edited after writing. wiki/ is the project memory, written only
by the librarian per .claude/rules/wiki-conventions.md. Spec and planner read wiki/index.md first,
at most four pages, then source. Every wiki claim links its source file; inferences are tagged NOT VERIFIED.

## Safety (also enforced by .claude/settings.json)
- Never git push, merge, force-reset, or delete branches.
- Never modify .claude/ or pipeline/queue.md. Only the librarian modifies wiki/.
- Write pipeline/state.json after every step so a crashed run can resume.

# gstack
Use /browse from gstack for all web browsing; never use mcp__claude-in-chrome__* tools.
Skills used by this pipeline: /spec /investigate /plan-eng-review /qa-only /review /ship
