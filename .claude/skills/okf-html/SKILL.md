---
name: okf-html
description: Author and manage OKF/HTML notes — knowledge as plain HTML documents where the link graph is the knowledge graph. Use when creating, editing, linking, tagging, or organising notes in any app built on the okf-html gem / okf-html-rails engine (notes_app, agent_app, future hosts); when adding typed links, collections, templates, or vocabulary terms; or when answering "how does OKF represent X". For the format spec itself, read SPEC.md (canonical copy in the okf-html repo).
---

# OKF/HTML — authoring and managing notes

OKF/HTML represents knowledge as ordinary, self-describing HTML documents. A note
is a complete HTML file. Its `<head>` carries identity and metadata; its `<body>`
is the editable content. Links between notes are typed edges, so the link graph
*is* the knowledge graph. There is no new file type, no RDF/YAML sidecar — the web
platform is the format.

Canonical spec: `SPEC.md` at the root of `github.com/br3nt/okf-html` (public). Read
it for anything below in depth — this skill is the working summary.

## The core model (read this before authoring)

- Everything is a note. The vocabulary, templates, collections, help, even the
  spec are themselves notes. To extend the system you author documents *in* it.
- Identity is a uuid, assigned once and stable forever. It survives renames and
  moving a note between apps. The canonical link is `/n/<uuid>`; `/n/<slug>` is a
  human convenience that resolves to the same note.
- The body is HTML you control. The head (identity, timestamps, tags, links, rev
  mirrors) is derived and managed by the library — do not hand-author it.
- Files are truth (§1). The store is the source of record; the search/graph index
  is derived and rebuildable from it.

## Don't assemble HTML by hand — go through the facade

Every host built on the gem exposes a repository. Create and manage notes through
it; never write the `<head>`, slugs, or rev mirrors yourself.

```ruby
repo.create(title: "Routing", content: "<p>How requests map to actions.</p>",
            tag_names: ["guide"])
repo.find(uuid_or_slug)          # => OKF::Note
repo.update(uuid_or_slug, content: "<p>…revised…</p>")
repo.delete(uuid_or_slug, dependent: :nullify)   # or :restrict / :destroy
repo.all                          # every note, most-recently-updated first
repo.search("query")              # blank query lists all
repo.reconcile                    # rebuild index + repair every rev mirror
```

In the Rails engine the repository hangs off a container: `node.okf.create(...)`
(any model that `include OKF::Container`). In the pure gem you build it directly:
`OKF::Repository.new(store: OKF::Store::Filesystem.new(root:))`.

## Links are the knowledge — author them as typed edges

The only thing the *body* must get right is its links, because they are the graph.

- Internal link: `<a href="/n/<uuid-or-slug>">…</a>`. This becomes a graph edge.
- Typed link: add a `rel` — `<a rel="chapter" href="/n/routing">Routing</a>`. The
  library reads `rel` to type the edge and materialises the inverse as a "rev
  mirror" on the target note (§7), so backlinks are automatic. Never hand-write
  the mirror.
- Tags: `<a href="/tags/<tag>" rel="tag">` in the body, or pass `tag_names:`.

### The naming rule (§6.1) — name the relationship, not the position

Use a `rel` that names a real-world role or relationship (`chapter`, `author`,
`bibliography`, `depends-on`), never a position in a list (`next`, `prev`,
`first`, `last`, `up`, `parent`). Positional words are vague and the library flags
them as discouraged. Sequence is derived by walking a collection's list (§8), not
asserted per-link. When you need "the next chapter", that falls out of the
collection order — don't encode it as a `rel`.

## Collections, templates, vocabulary

- Collection (§8): a note whose body lists other notes (`<ol>/<ul>` of `/n/` links).
  Membership and order are derived from that list; nesting a collection inside a
  collection makes membership transitive. A "node bundle" / "workspace" is just a
  collection. Membership links live inside list items; a "see also" in a paragraph
  is a plain edge, not membership.
- Template (§9): a note with a `<template>` prototype (slots / `[data-field]`) that
  stamps out other notes; associations are declared as `<link rel="okf:…">`.
- Vocabulary (§6): the catalogue of allowed `rel`/meta terms, their inverses, and
  the discouraged words — `OKF::Vocabulary`. Profiles are themselves documents, so
  a host extends the vocabulary by authoring a profile note, not by editing config.

## title vs effective_title (common foot-gun)

`title` is the raw, explicit title and is *blank* when a note takes its name from
its first line. `effective_title` is the derived display name (explicit title →
first line → "Untitled"). Use `effective_title` for lists and headings; bind an
edit field to raw `title` so an implied-title note keeps an empty input instead of
persisting the derived name. Over an API, send both.

## Build with hypermedia, not JSON

OKF is HTML all the way down, including over the wire — there is no JSON, HTML is
the data contract. When building a UI or API on a host, serve HTML: a list of
notes is a collection (§8) — an HTML document of `/n/` links, not a JSON array;
editor autocomplete and the vocabulary are HTML fragments the client reads or JST
renders; mutations send form params and return the rendered note HTML (Turbo). A
machine consumer parses the HTML (extra structure goes in microdata/`data-*`),
never a JSON fork. If you're about to serialise notes or links to JSON, stop — you
already have an HTML representation; use it. Full patterns: `doc/hypermedia.md` in
the okf-html repo.

## When making changes

- Author the body; let the library own the head, slug, and rev mirrors.
- After bulk edits or a restore, run `reconcile` to rebuild the index and repair
  mirrors.
- Identity is forever — never regenerate a uuid to "fix" a note; rename instead
  (rename rewrites no files, only the mirrors whose href moved).
- If a host needs a behaviour the facade can't express, that's a gap worth an
  issue on `github.com/br3nt/okf-html`, not a reason to reach past it into the
  store/index.
