# Changelog — Vidhana

## 1.0.0 — 2026-09-13
- Unattended pipeline: orchestrator + spec, planner, plan-reviewer, builder, qa, reviewer; isolated ship agent.
- Automated gates: SubagentStop hook (`gate.sh`, 13-case self-test), round caps, permission deny list, `GSTACK_SESSION_KIND=spawned`.
- LLM-wiki project memory: `librarian` agent, `wiki/` skeleton, conventions, deterministic `wiki-lint.sh`.
- Cloud: `scripts/bootstrap.sh`, SessionStart hook, container recipe, CI workflow template.
- Docs: verification report with evidence table, build/test/getting-started guides, wiki structure and usage guides, Mermaid diagram.
