# Changelog

Both gems version together and track the spec: the minor follows SPEC.md's
version (spec 0.1 → 0.1.x), with patch releases for gem iterations. Format roughly
follows Keep a Changelog.

## [Unreleased]

### Added

- Container scoping in the index: entries carry a container id and `all` /
  `search` / `tagged` take a `scope:` (nil/:all/:global, or an id-set for a node
  and its descendants — the host passes the set). `all_tags` for the tag
  namespace. `Repository` gains `container:`, `tagged`, and `move(uuid, to:)`.
- `OKF::Rails::Index` — a SQL-backed, workspace-global index (okf_notes +
  okf_edges + okf_taggings) conforming to the Index interface, selectable via
  `OKF.config.index_builder`. `rails g okf:install` ships the migration +
  initializer.
- The note editor as a no-build engine asset: `okf/editor` (`window.OKF.mountEditor`)
  with configurable endpoints, the vendored Tiptap/ProseMirror ESM, importmap
  pins, and CSS — toolbar, autosave, lists/checklists, wikilinks + `rel` picker,
  in-content `#tags`. Everything over the wire is HTML.

## [0.1.0] — 2026-06-27

First tagged release: a complete, tested implementation of the OKF/HTML 0.1 spec
as a pure Ruby core plus a Rails engine, with the data layer ready for hosts to
embed notes.

### okf-html (pure core)

- `OKF::Document` — render a note to a full self-describing HTML document and
  parse one back (identity, timestamps, tags, metadata, typed links, rev mirrors).
- `OKF::Vocabulary` — rel/meta catalogue, inverses, schemes, head-link rels, and
  the discouraged positional words (§6 / §6.1).
- `OKF::Template` / `OKF::TemplateAssociation` — `<template>` instantiation and the
  association DSL serialised to/from `<link rel="okf:…">` (§9).
- `OKF::Note` — a plain value object implementing the note interface.
- The three seams: `OKF::Store` (`Filesystem` default + `Memory`), `OKF::Index`
  (derived, rebuildable, in-memory), and `OKF::Repository` — the deep facade:
  `create` / `find` / `update` / `delete` / `all` (alias `list`) / `search` /
  `reconcile`, owning identity, slugs, rendering, rev-mirror materialisation (§7)
  and dependent-delete (§10).
- `Repository#all` / `#list` return every note, most-recently-updated first;
  `search("")` / `search(nil)` returns the same, so one call searches and lists.
- `Index::Entry` carries `created_at` / `updated_at` for cheap body-less listing.

### okf-html-rails (engine)

- `OKF::Container` concern — `include` it to give any model an `okf` repository
  scoped to itself (`model.okf.create/find/update/delete/all/search/reconcile`).
- `OKF::Rails::Configuration` — `store_root` (default
  `Rails.root.join("storage/okf", Rails.env)`, segmented by environment so
  dev/test/prod never share files) and a `store_builder` seam to take over
  storage entirely.
- `OKF::Rails::Engine` — isolates the `OKF` namespace. Controllers, routes and the
  Tiptap/JST editor are a following phase.

### Docs

- `SPEC.md` vendored as the canonical spec.
- `doc/hypermedia.md` — build on OKF with hypermedia, not JSON.
- `doc/implementing.md` — porting to other languages/frameworks + conformance
  checklist.
- `INTEGRATION_BRIEF.md` — for new consumers.

[0.1.0]: https://github.com/br3nt/okf-html/releases/tag/v0.1.0
