# Changelog

Both gems version together and track the spec: the minor follows SPEC.md's
version (spec 0.1 → 0.1.x), with patch releases for gem iterations. Format roughly
follows Keep a Changelog.

Each release carries its own **Upgrading** notes inline (what a consumer wires up
to adopt the change); the full how-to for each capability is in the engine
`README.md`. To pin a release, see the git/tag refs in the install instructions.

## [0.1.5] — 2026-07-05

### Added

- `OKF::Index::Entry` now carries `template_uuid` and `metadata` (SPEC §9.2 and
  §3), populated from the parsed document alongside the fields it already
  carried — so a host can ask "instances of this type" and "notes whose field
  X is Y" without re-parsing every document. `OKF::Filter` gains two
  predicates that use them: `type:<slug-or-uuid>` (instances of a template,
  resolved by slug or uuid) and `meta:<name>` / `meta:<name>:<value>` (a
  custom metadata field is present, or equals a value). Pure Ruby, no schema
  change for the in-memory index (mirrors how 0.1.2 added `pinned:`/`template:`
  the same way).
- `OKF::Rails::Index` (the SQL-backed index) now persists `template_uuid` as a
  column on `okf_notes` and custom metadata fields in a new `okf_note_metadata`
  table (`note_uuid`, `name`, `value`, `scheme`), rewritten on every reindex the
  same way `okf_taggings` already is — so `type:`/`meta:` filter the SQL index
  exactly like the in-memory one, with no per-request document parsing.
  `rails g okf:install` now also writes
  `add_template_query_support_to_okf_index.rb`, a second, additive migration.

### Upgrading

- In-memory index / `OKF::Filter`: none — new fields default to blank, new
  predicates are additive.
- SQL-backed index: run `rails g okf:install` again to fetch the new migration
  template, then `rails db:migrate`. An install that already has the SQL index
  need only pick up the one new file (the pre-existing `create_okf_index.rb`
  migration is untouched and won't re-run); if the generator refuses to
  overwrite `config/initializers/okf.rb`, copy just
  `add_template_query_support_to_okf_index.rb.tt` from
  `lib/generators/okf/install/templates/` by hand. `reconcile` backfills the
  new columns/table for notes indexed before the upgrade.

## [0.1.4] — 2026-07-02

### Added

- Conformance fixtures (`fixtures/parse.yml`, `fixtures/render.yml`) covering the
  SPEC.md examples, wired into `okf-html`'s test suite via
  `test/conformance_fixtures_test.rb` so the spec and the implementation can't
  silently drift. `fixtures/README.md` documents the fixture format for other
  language implementations.
- `llms.txt` for LLM-assisted consumers, and `AGENTS.md` for agents working in
  this repo.
- The `okf-html` authoring skill (`.claude/skills/okf-html/SKILL.md`), referenced
  from `llms.txt`.

### Changed

- `INTEGRATION_BRIEF.md` and both README.md files corrected to link to the real
  SPEC.md sections and describe current behaviour truthfully (docs-only fix, no
  behaviour change).

### Upgrading

- None. Docs and test infrastructure only — no API or storage-format change.

## [0.1.3] — 2026-06-29

### Added

- JST components for the engine (hypertext as the API). `app/views/okf/_components.html.erb`
  defines `<okf-editor>` and `<okf-graph>` JST components that wrap the `okf/editor`
  and `okf/graph` assets, so a host embeds them declaratively — write the custom
  element, JST upgrades it, `once()` mounts the widget and returns its teardown.
  Aligns OKF with JST's philosophy (HTML is the wire format, props down / events
  up). Browser-verified end to end.

### Upgrading

- Optional. The imperative `window.OKF.mountEditor` / `mountGraph` API is
  unchanged. To embed declaratively, load the JST runtime (v0.4.1+; serve its
  modules undigested from `public/jst`, load `/jst/jst.js` — see JST's
  integration guide), `render "okf/components"` once, then write `<okf-editor
  …>` / `<okf-graph …>`. The host owns the JST runtime; the engine ships only the
  component definitions + the `okf/editor` / `okf/graph` assets.

## [0.1.2] — 2026-06-28

### Added

- The graph visualiser (issue #2). `OKF::Filter` parses a GitLab-style query
  (`tag:`/`tag:in:`/`tag:none:`, `rel:`, `inbound:`, `collection:`, `pinned:`,
  `template:`, `created:`/`updated:` with `>`/`<`/`A..B`/`last:Nd`/bare-day,
  `text:`, `fuzzy:`; tokens AND, negate with `-`/`!`) over any index in any scope.
  `OKF::Graph` builds nodes + closed typed edges and serialises the subgraph as
  HTML. `Repository#filter` / `#graph` are the ergonomic entry points. The engine
  ships `okf/graph` — a no-build, dependency-free force-directed SVG renderer with
  a chip filter bar — plus `okf/graph.css`. Browser-verified.

### Upgrading

- Wire one host route that serves the subgraph as HTML —
  `render html: current_node.okf.graph(params[:filter]).to_html.html_safe` — and
  mount `okf/graph` against it (`mountGraph(el, { graphUrl, filter })`), or use
  the `<okf-graph>` JST component (0.1.3). The filter language is pure Ruby, so
  the same query also drives a list. No schema change.

## [0.1.1] — 2026-06-28

### Added

- Container scoping in the index: entries carry a container id and `all` /
  `search` / `tagged` take a `scope:` (nil/:all/:global, or an id-set for a node
  and its descendants — the host passes the set). `all_tags` for the tag
  namespace. `Repository` gains `container:`, `tagged`, and `move(uuid, to:)`.
- `OKF::Rails::Index` — a SQL-backed, workspace-global index (okf_notes +
  okf_edges + okf_taggings) conforming to the Index interface, selectable via
  `OKF.config.index_builder`. `rails g okf:install` ships the migration +
  initializer.
- The note editor as a no-build engine asset: `okf/editor`
  (`window.OKF.mountEditor(el, opts) -> { getHTML, destroy }`) with configurable
  endpoints, the vendored Tiptap/ProseMirror ESM, importmap pins, and CSS —
  toolbar, autosave, lists/checklists, wikilinks + `rel` picker, in-content
  `#tags`. Optional, host-gated properties (custom `<meta>` / head `<link>`) and
  template-associations panels (enable the latter with `templatesUrl`). Browser-
  verified end to end; everything over the wire is HTML.

### Upgrading

- Pin both gems from the repo with `git:`, `glob:` pointing at each gem's
  `.gemspec`, and `tag: "v0.1.x"`. Loading the engine auto-registers the editor
  assets + importmap pins.
- Editor: add `stylesheet_link_tag "okf/editor"` + `javascript_importmap_tags`,
  then `window.OKF.mountEditor(el, { content, updateUrl, wikilinksUrl,
  vocabularyUrl })`. Your endpoints speak **HTML, not JSON**: `updateUrl` takes a
  form PATCH (`note[content]=…`) and returns HTML with a `[data-slug]`;
  `wikilinksUrl` / `vocabularyUrl` return HTML the editor parses. See README.
- SQL index (for cross-node search / app-wide tags / `move`): `rails g
  okf:install && rails db:migrate`, then `OKF.config.index_builder = ->(_c) {
  OKF::Rails::Index.new }` with a shared `store_builder`. Queries take `scope:`
  (a container, a subtree id-set the host computes, or `:global`).

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

[0.1.5]: https://github.com/br3nt/okf-html/releases/tag/v0.1.5
[0.1.4]: https://github.com/br3nt/okf-html/releases/tag/v0.1.4
[0.1.3]: https://github.com/br3nt/okf-html/releases/tag/v0.1.3
[0.1.2]: https://github.com/br3nt/okf-html/releases/tag/v0.1.2
[0.1.1]: https://github.com/br3nt/okf-html/releases/tag/v0.1.1
[0.1.0]: https://github.com/br3nt/okf-html/releases/tag/v0.1.0
