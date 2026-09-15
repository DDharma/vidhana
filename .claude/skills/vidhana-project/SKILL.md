---
name: vidhana-project
description: Fill or update the PROJECT block of CLAUDE.md (NAME, STACK, RULES, DESIGN) for a Vidhana pipeline, from a PRD file or by interview. Works for a fresh kit install and for adopting Vidhana into an existing repo that already has its own CLAUDE.md. Use when starting a new project, adopting Vidhana into an existing codebase, or when the stack, test command, project rules or design source have changed.
argument-hint: "[path/to/prd.md]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls *), Bash(cat *), Bash(grep *), Bash(sed *), Bash(find *), Bash(git *), Bash(node *), Bash(npm *), Bash(python3 *)
---

# Vidhana — set up the PROJECT block

You are filling the four PROJECT lines at the top of `CLAUDE.md`. Everything below
`# VIDHANA PIPELINE CONTRACT` is the pipeline itself — **never edit it.**

`$ARGUMENTS` may be a path to a PRD, spec or README. If given, read it first. If empty, interview.

## Why this matters

These four lines are read by every agent on every run. Two are load-bearing:

- **STACK** gives QA the exact commands it runs. Vague, and QA cannot verify anything.
- **RULES** is the *only* project-wide constraint, and **two review gates REVISE on violations
  of it**. A vague RULES line silently disarms both.

## Step 0 — Classify CLAUDE.md before touching it

Run these with Bash, one call, and read the output:

```bash
ls -l CLAUDE.md
grep -c 'VIDHANA PIPELINE CONTRACT' CLAUDE.md
grep -c '^NAME:' CLAUDE.md
grep -n '<project name>' CLAUDE.md
```

A missing file or a zero count is itself the answer — read the numbers, don't treat an error as failure.

| file | contract | name-line | State | Action |
|---|---|---|---|---|
| present | 1 | 1 + placeholder | Kit installed, never configured | Fill the four lines |
| present | 1 | 1, real values | Already configured | Show current values, confirm before changing |
| present | **0** | 0 | **Foreign CLAUDE.md — this repo had its own** | Go to Step 0b. **Do not overwrite it.** |
| ABSENT | — | — | Kit not installed here | Stop. Tell the user to install the kit first |

### Step 0b — Adopting into a repo that already has a CLAUDE.md

This is the dangerous case. Their file is theirs and may hold real operating knowledge.

1. **Read it in full and show it back to the user.** Never Write over it.
2. **Mine it for RULES.** Existing notes are usually where the real constraints live —
   "don't commit secrets", "ask Priya before touching billing", "never edit generated/".
   Propose these as RULES clauses; they are more accurate than anything you'd invent.
3. **Propose a merged file**: the four PROJECT lines, then the pipeline contract copied verbatim
   from the kit, then their original content preserved under a `# Project notes` heading.
4. **Show the proposal and get explicit confirmation before writing.** If they decline, stop and
   let them merge by hand.

If the pipeline contract is missing entirely, the kit is not installed in this repo — say so.
Everything downstream depends on that contract being present and unmodified.

## Step 1 — Look before you ask

Never ask what you can read:

```bash
ls -a
cat package.json
cat pyproject.toml go.mod Cargo.toml composer.json Gemfile build.gradle
```

A manifest usually gives you language, framework, test command and run command. On an existing
project also check what the tests actually are (`ls test tests spec __tests__ 2>/dev/null`) and
skim the source layout. Confirm what you inferred — don't interview from zero.

## Step 2 — Determine the four values

### NAME
Short, lowercase. The repo or product name.

### STACK
`<language + framework>; test: <exact command>; run: <exact command>`

- **Exact commands, not descriptions.** `test: npm test` — not "uses Jest".
- The test command must **run and exit**. Never watch mode: `vitest run`, not `vitest`.
- The run command is what QA uses to exercise criteria. If it starts a long-lived server, say so
  and prefer a harness the tests drive directly — a QA agent that starts a server which never
  exits blocks its own shell until timeout.
- No run command (a library, a CLI)? Write `run: n/a`.
- **Existing project:** take these from `package.json` scripts or the Makefile, not from guesswork,
  and verify the test command actually passes today before you record it.

### RULES
`<dependency policy>; <files never to touch>; <conventions>`

Every clause must be **checkable by reading a diff**:

- Good: `no new npm dependencies; never touch src/legacy/; all DB access through src/repo/`
- Good: `every component uses DESIGN.md tokens — no hard-coded colours, spacing or font sizes`
- Useless: `write clean code; follow best practices`

On an existing project, derive rules from what the code already does — an import boundary that
holds everywhere, a directory nobody edits, a dependency policy visible in the manifest. Confirm
each with the user. If they offer a vague rule, push once for the concrete version.

### DESIGN
A Figma file URL of the design system, or `none`.

`none` → the designer generates `DESIGN.md` on the first frontend item. A Figma URL needs a Figma
MCP server connected — say so if they give one. Backend-only → `none`, and the designer never runs.

## Step 3 — Write

Use **Edit**, never Write — a whole-file Write risks losing the contract or their notes.
Replace only the four lines under `# PROJECT`. Leave the header comment and everything from
`# VIDHANA PIPELINE CONTRACT` onward byte-for-byte unchanged.

Verify after writing:

```bash
sed -n '1,8p' CLAUDE.md
grep -c 'VIDHANA PIPELINE CONTRACT' CLAUDE.md
```

The count must still be 1. If it is 0 you destroyed the contract — restore it before doing anything else.

## Step 4 — Report and stop

Print the four lines. Then one line each on:
- what you inferred from the repo vs. what they told you
- any assumption they should check
- that `/vidhana-queue` is the next step

Do **not** continue into queue generation. That is a separate command on purpose, so the project
block is set once while the queue is regenerated many times.

## Worked example

```
NAME: slate
STACK: Node 20+, ESM, zero dependencies; test: npm test (node --test); run: node src/server.js (port 3000)
RULES: no npm dependencies of any kind, node: builtins only; all HTTP handling in src/server.js which exports handle(req,res) and only calls listen() as the main module, so tests never open a socket; all persistence through src/store.js; never hand-edit data/*.json
DESIGN: none
```

The `handle(req,res)` clause is not style advice — it stops QA starting a server that never exits.
Rules that encode operational hazards are worth more than rules that encode taste.
