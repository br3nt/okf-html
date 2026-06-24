# OKF/HTML

Notes as complete, self-describing HTML documents — the [OKF/HTML](https://br3nt.github.io/okf/)
spec, implemented as a reusable library plus a Rails engine.

This repository holds two gems that version together:

- [`okf-html`](okf-html/) — the pure-Ruby format core: the document serializer,
  vocabulary, templates and the ported association DSL. No Rails, no I/O.
- [`okf-html-rails`](okf-html-rails/) — a mountable Rails engine that wires the
  core into a host application: the container association, an ActiveRecord index,
  controllers, the editor UI, and generators.

A host that wants notes embeds `okf-html-rails`; anything that just needs to read
or write the format depends on `okf-html` alone.

See `ARCHITECTURE.md` in the reference application (notes_app) for the extraction
decisions, the interface design, and the migration plan.
