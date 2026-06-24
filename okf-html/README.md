# okf-html

Pure-Ruby implementation of the [OKF/HTML](https://br3nt.github.io/okf/) spec:
notes are complete, self-describing HTML documents, and the link graph between
them is the knowledge graph.

This gem is the format core. It performs no I/O and depends on no web framework —
its collaborators (a note, an owner) are duck-typed. The Rails engine
`okf-html-rails` wires it into a host application; this gem can be used on its
own anywhere Ruby runs.

## What's here

- `OKF::Document` — renders a note's attributes to a full HTML document and
  parses one back (`render` / `parse`). The head carries identity, timestamps,
  tags, custom metadata and links; the body is the editable content.
- `OKF::Vocabulary` — the rel/meta term catalogue, inverses (for rev mirrors),
  metadata schemes, head-link rels, and the discouraged positional words.
- `OKF::Template` — instantiates a `<template>` prototype, filling `<slot>`s and
  `[data-field]`s and stripping authoring scaffolding.
- `OKF::TemplateAssociation` — the association DSL ported from Rails
  (has-many / has-one / belongs-to with as / inverse / dependent / through /
  ordered / optional / polymorphic), serialised to and from `<link rel="okf:…">`.
- `OKF::Note` — a plain value object carrying a note's attributes; what the
  Repository creates and renders when a host has no model of its own.

## The seams

Three narrow interfaces let a host swap storage and indexing without touching the
format:

- `OKF::Store` — dumb byte storage keyed by uuid: `read` / `write` / `delete` /
  `exist?` / `each_key`. Ships `Store::Filesystem` (file-is-truth, the default)
  and `Store::Memory`.
- `OKF::Index` — a derived, rebuildable view over a store: `resolve`, `search`,
  `backlinks` (for rev mirrors), `tagged`, `members` (a collection in order).
  In-memory default; a host with a database provides its own.
- `OKF::Repository` — the one deep facade: `create` / `find` / `update` /
  `delete` / `search` / `reconcile`. It assigns identity, derives slugs, renders
  documents, materialises rev mirrors on linked notes, and applies
  dependent-delete policies — composing a Store and an Index underneath.

## The note interface

`OKF::Document.render(note)` expects `note` to respond to: `uuid`, `slug`,
`effective_title`, `created_at`, `updated_at`, `tag_names`, `pinned?`, `content`,
and (optionally) `template?`, `template_uuid`, `metadata`, `links`,
`associations`, `incoming_links`. Anything providing those works — there is no
ActiveRecord dependency.

## Status

Tracks the spec version (spec 0.1 → gem 0.1.x). Not on RubyGems yet; consumed as
a path/git gem during development. See `ARCHITECTURE.md` in the reference app for
the extraction plan.
