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
