# OKF/HTML

Notes as complete, self-describing HTML documents — the [OKF/HTML](https://github.com/br3nt/okf-html/blob/main/SPEC.md)
spec, implemented as a reusable library plus a Rails engine.

OKF/HTML keeps knowledge in the format the web already understands. Instead of
Markdown plus YAML front matter or a JSON sidecar, each note is one complete HTML
document: the body is readable content, the head carries identity and metadata,
and ordinary links are the graph. You can open the file in a browser, parse it
with any HTML library, rebuild indexes from disk, and move the note between apps
without translating it through a private container format.

This repository holds two gems that version together:

- [`okf-html`](okf-html/) — the pure-Ruby format core: the document serializer,
  vocabulary, templates and the ported association DSL. No Rails, no I/O.
- [`okf-html-rails`](okf-html-rails/) — a mountable Rails engine that wires the
  core into a host application: the container association, an ActiveRecord index,
  controllers, the editor UI, and generators.

A host that wants notes embeds `okf-html-rails`; anything that just needs to read
or write the format depends on `okf-html` alone.

## Runnable core example

From the repo root:

```bash
ruby -Iokf-html/lib <<'RUBY'
require "okf/html"

repo = OKF::Repository.new(store: OKF::Store::Memory.new)
note = repo.create(
  title: "Sourdough Starter",
  content: %(<p>Feed daily. See <a rel="related" href="/n/bread">bread</a>.</p>),
  tag_names: ["baking", "bread"]
)

puts repo.store.read(note.uuid)
RUBY
```

That prints a complete OKF/HTML document with a generated uuid, canonical link,
timestamps, tags, and the body you supplied. Hosts should go through the
Repository facade like this; do not hand-write heads, slugs, or rev mirrors.

See `ARCHITECTURE.md` in the reference application (notes_app) for the extraction
decisions, the interface design, and the migration plan.
