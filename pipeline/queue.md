## item: T-001
type: feature
title: Add GET /health returning {"ok": true}
acceptance:
- GET /health returns HTTP 200 with body {"ok": true}
- a test covers it
- existing tests still pass
