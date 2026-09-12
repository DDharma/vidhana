---
name: ship
description: MANUAL ONLY. Ships an approved branch via gstack /ship. Not spawnable by the orchestrator.
model: sonnet
tools: Read, Bash(git *), Bash(gh *)
skills: [ship]
maxTurns: 40
---
Read pipeline/reports/<id>.md. If STATUS is not DONE, refuse and explain. Otherwise run /ship for feat/<id>.
