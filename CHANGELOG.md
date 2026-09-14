# Changelog — Vidhana

## 1.1.0 — 2026-09-14
- Design layer: `designer` agent (opus) runs after spec and before the planner for `layer: frontend|fullstack` items; backend items skip it.
- `DESIGN.md` at repo root is the project design system — extracted from Figma through the Figma MCP when `CLAUDE.md` has `DESIGN: <url>`, otherwise generated with gstack `/design-consultation`. Created once, refreshed only by `type: design-sync`.
- Per-item `pipeline/designs/<id>.md` (screens, states, token gaps, Design acceptance); planner, plan-reviewer, builder, QA and reviewer read it.
- Queue item fields `layer:` and `design:`; spec writes a `Layer:` line when the item has none.
- Gate: designer cannot stop until both design files exist (self-test now 17 cases). `DESIGN.md` fenced on every other agent.
- Docs: build-guide §5c, getting-started layer section, test-guide section D, verification rows 23–28, diagram; stale agent and test counts corrected.

## 1.0.0 — 2026-09-13
- Unattended pipeline: orchestrator + spec, planner, plan-reviewer, builder, qa, reviewer; isolated ship agent.
- Automated gates: SubagentStop hook (`gate.sh`, 13-case self-test), round caps, permission deny list, `GSTACK_SESSION_KIND=spawned`.
- LLM-wiki project memory: `librarian` agent, `wiki/` skeleton, conventions, deterministic `wiki-lint.sh`.
- Cloud: `scripts/bootstrap.sh`, SessionStart hook, container recipe, CI workflow template.
- Docs: verification report with evidence table, build/test/getting-started guides, wiki structure and usage guides, Mermaid diagram.
