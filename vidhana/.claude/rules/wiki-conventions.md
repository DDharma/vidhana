# Wiki conventions (schema layer for wiki/)

Raw sources are under pipeline/ and are never edited. The wiki under wiki/ is written only by the
librarian agent. Spec and planner read it; they never write it.

## Six rules
1. Provenance on every claim. Each statement links to the pipeline/ file or commit it came from,
   e.g. `(pipeline/qa/F-001-r2.md)`. Anything inferred rather than read is prefixed `NOT VERIFIED —`.
2. Shape, not values. Describe structure; never quote a value that moves: no line counts, no commit
   SHAs in prose, no "the five modules". Link to the live thing instead. (log.md and items/ are exempt
   from the SHA rule because they are historical records.)
3. Never delete, supersede. A wrong page gets a `superseded-by: [[...]]` line and stays linked.
4. Index is complete and unique. Every page appears in wiki/index.md exactly once.
5. Log before stop. Every ingest or lint appends one `## [date] mode | id title` line to wiki/log.md.
6. One writer. Only the librarian writes wiki/.

## Page templates
### modules/<name>.md
# <name>
**Purpose** — one paragraph.
**Key files** — repo paths only.
**Invariants** — each with its source link.
**Gotchas** — each linking the review/QA file.
**History** — [[items/<id>]] list.

### decisions/<yyyy-mm-dd>-<slug>.md
# <title>
**Context** · **Decision** · **Consequences** · `superseded-by:` (empty until reversed) · source: pipeline/plans/<id>.md

### items/<id>.md
# <id> — <title>
**Asked** (from spec) · **Built** (from build report) · **Rounds** plan/qa/review · **QA caught** · **Review caught** ·
**Open risks** · **Raw** — links to every pipeline/ file for this id.

## Link syntax
`[[modules/auth]]` resolves to wiki/modules/auth.md. Repo files are plain backticked paths.
