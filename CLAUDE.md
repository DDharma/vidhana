# PROJECT  ← edit these four lines per project
NAME: <project name>
STACK: <language + framework; exact test command; exact run command>
RULES: <dependency policy; files never to touch; conventions>
DESIGN: <Figma file URL of the design system | none (the designer generates DESIGN.md)>

# VIDHANA PIPELINE CONTRACT (do not edit per project)

You are running Vidhana, an unattended engineering pipeline. There is no human in the loop.
Work items live in pipeline/queue.md. Process them one at a time, top to bottom.
Never start the next item until pipeline/reports/<id>.md exists for the current one.

## Modes (from each item's `type:` field)
- greenfield  : nothing exists yet → spec includes scaffold, tooling, first runnable test.
- feature     : existing codebase → spec cites the files it will touch.
- bug         : start from current state → spec step runs /investigate (root cause), then continue at Plan.
- design-sync : refresh DESIGN.md from Figma (or regenerate it) → designer only, then report and librarian.

## Layers (from the item's optional `layer:` field, else the spec's `Layer:` line, else fullstack)
- backend             : no design step.
- frontend | fullstack : designer runs after spec, before planner.
An item may also carry `design: <figma frame url>` for the screens of that one feature.

## Steps and required artifacts (an agent that does not write its artifact has FAILED that round)
1 spec          → pipeline/specs/<id>.md                 (includes a `Layer:` line)
2 designer      → DESIGN.md (only if missing, or design-sync) + pipeline/designs/<id>.md
                  frontend | fullstack | design-sync only; the orchestrator commits both before step 3
3 planner       → pipeline/plans/<id>.md
4 plan-reviewer → pipeline/reviews/<id>-plan-r<N>.md    last line: VERDICT: APPROVE | REVISE
5 builder       → branch feat/<id> + pipeline/reports/<id>-build.md
6 qa            → pipeline/qa/<id>-r<N>.md              last line: VERDICT: PASS | FAIL
7 reviewer      → pipeline/reviews/<id>-code-r<N>.md    last line: VERDICT: APPROVE | REVISE
8 librarian     → wiki/items/<id>.md + updated wiki/index.md + one new line in wiki/log.md
                  runs after every DONE or BLOCKED; mode lint every 5th item
9 ship          → NEVER invoked by this pipeline. A human runs `claude --agent ship` separately.

## Loop rules (automated gates)
- designer             → no verdict and no loop; the gate holds it until both files exist.
- plan-reviewer REVISE → planner again with the review path attached.  Max 3 plan rounds.
- qa FAIL              → planner again (not builder) with the QA path attached.  Max 3 QA rounds.
- reviewer REVISE      → builder again with the review path attached.  Max 2 review rounds.
- Any max exceeded     → write pipeline/reports/<id>.md with STATUS: BLOCKED, commit, move on. Never retry.
- No VERDICT line      → treat as the failing verdict for that gate.

## Reporting — pipeline/reports/<id>.md must contain
STATUS (DONE|BLOCKED) · branch · commit list · spec summary · Assumptions copied from the spec ·
layer · design source (figma | generated | n/a) · rounds used per gate · final QA verdict ·
final review verdict · open risks · start/finish time.

## DESIGN SCHEMA
DESIGN.md at the repo root is the project design system: colour, typography, spacing, components.
It is a local copy of Figma (or a generated baseline) so no agent goes back to Figma per item. Its first
line records `source: figma <url> @ <date>` or `source: generated @ <date>`. Only the designer writes it,
and only when it is missing or the item is design-sync. pipeline/designs/<id>.md holds one item's
screens and states, referencing DESIGN.md tokens by name. Every agent doing UI work reads both first.

## WIKI SCHEMA
pipeline/ holds raw sources and is never edited after writing. wiki/ is the project memory, written only
by the librarian per .claude/rules/wiki-conventions.md. Spec and planner read wiki/index.md first,
at most four pages, then source. Every wiki claim links its source file; inferences are tagged NOT VERIFIED.

## Safety (also enforced by .claude/settings.json)
- Never git push, merge, force-reset, or delete branches.
- Never modify .claude/ or pipeline/queue.md. Only the librarian modifies wiki/. Only the designer modifies DESIGN.md.
- Write pipeline/state.json after every step so a crashed run can resume.

# gstack
Use /browse from gstack for all web browsing; never use mcp__claude-in-chrome__* tools.
Skills used by this pipeline: /spec /investigate /design-consultation /design-shotgun /plan-eng-review /qa-only /review /ship
