# Agent Guide

Use the Repository facade first. Create, find, update, delete, list, search,
filter, graph, and reconcile through `OKF::Repository` or a Rails container's
`node.okf` repository. Do not hand-write note heads, canonical links, timestamps,
slugs, template association head links, or `rev` mirrors; those are derived by the
library.

Start here:

- `SPEC.md` — the format contract.
- `doc/implementing.md` — implementation seams and conformance checklist.
- `doc/hypermedia.md` — HTML is the wire contract; do not add JSON shadows.
- `.claude/skills/okf-html/SKILL.md` — agent workflow for authoring and managing
  OKF/HTML notes.
- `fixtures/` — language-neutral render and parse vectors, hand-written from
  `SPEC.md` and enforced by `okf-html/test/conformance_fixtures_test.rb`.

For Ruby hosts, the pure core is `okf-html`; the Rails integration is
`okf-html-rails`. If a host needs behavior the Repository cannot express, treat
that as a facade gap to fix in this repo rather than reaching into Store or Index
from application code.
