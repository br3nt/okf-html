# Integrating okf-html into agent_app — briefing

You are integrating the `okf-html` gem (and its Rails engine `okf-html-rails`)
into agent_app. This document is your starting point. After you've wired up the
data layer and hit real friction, write down what you learned — that feedback
drives the next phase of the gem's design (the index schema and the global-tags
model are deliberately unfinished and waiting on it).

## The vision (why this gem exists)

OKF/HTML treats a note as a complete, self-describing HTML document. The note's
`<head>` carries its identity (a uuid), metadata, and typed links; the `<body>`
is the editable content. Because every note links to other notes, the link graph
*is* a knowledge graph. Files are the truth — a note is a file on disk you could
read without the app.

The goal is one deep core behind a few narrow interfaces, so a host app gets
notes, links, tags, collections, templates, and schemas without ever touching
the HTML serialization, the graph derivation, or the reconciler. That is the
John Ousterhout "deep modules, narrow interfaces" treatment: complexity pulled
down into the library, hosts stay thin.

## What agent_app needs from it (the requirements that shaped the design)

- A hierarchy of workspace nodes. Notes attach to a node.
- A node's bundle includes notes from descendant nodes — node maps to a
  collection, child node maps to a nested collection, the bundle is the
  collection's transitive membership. The host owns its tree; the library
  resolves membership and never walks your tree.
- Tags are global app-wide (one namespace across all nodes).
- Schemas/vocabulary are global across apps (a profile is a shared document, not
  per-node state).
- Pluggable storage, filesystem-is-truth by default.
- uuid is the canonical global identity — a note keeps its uuid when it moves
  between nodes or between apps. Slugs are per-scope human URLs.

## Where the code is

```
git@github.com:br3nt/okf-html.git   (private, SSH)
```

One repo, two gems that version together:

- `okf-html` — pure Ruby core, namespace `OKF`, no Rails, no I/O.
- `okf-html-rails` — the mountable engine (`OKF::Engine`) + the `OKF::Container`
  concern + configuration.

Add to agent_app's Gemfile:

```ruby
gem "okf-html",       git: "git@github.com:br3nt/okf-html.git", glob: "okf-html/*.gemspec"
gem "okf-html-rails", git: "git@github.com:br3nt/okf-html.git", glob: "okf-html-rails/*.gemspec"
```

(The two gemspecs live in subdirectories of the one repo, hence `glob:`. Pin a
tag once one exists; for now the default branch is fine.)

## The API you actually call

Include the concern in whatever owns notes — your workspace node model:

```ruby
class WorkspaceNode < ApplicationRecord
  include OKF::Container
end
```

That gives the model an `okf` repository scoped to itself:

```ruby
node.okf.create(title: "Idea", content: "<p>…</p>", tag_names: ["draft"])
node.okf.find(uuid_or_slug)        # => OKF::Note
node.okf.update(uuid_or_slug, title: "Better idea")
node.okf.delete(uuid_or_slug, dependent: :nullify)   # or :restrict / :destroy
node.okf.search("idea")            # => [OKF::Note, …]
node.okf.containing_collections(uuid_or_slug)         # collection membership / paging
node.okf.reconcile                 # rebuild index + re-render every note
```

An `OKF::Note` is a value object with: `uuid, slug, title, content,
created_at, updated_at, tag_names, pinned, template, template_uuid, metadata,
links, associations, incoming_links`. Plus `effective_title`, `slug_source`,
`pinned?`, `template?`.

Configure storage in an initializer:

```ruby
# config/initializers/okf.rb
OKF.configure do |c|
  c.store_root = Rails.root.join("storage/okf")
  # Or take storage over entirely (e.g. one datastore for every node):
  # c.store_builder = ->(container) { MyStore.new(container) }
end
```

By default each container (node) gets its own filesystem store, namespaced by
class + id (`workspacenode-42/<uuid>.html`), with a derived index over it. Swap
`OKF::Store::Filesystem` for `OKF::Store::Memory` or your own — anything with
`read/write/delete/exist?/keys/each_key` keyed by uuid string.

## What is done vs. not

Done and tested (pure core 34 runs, engine 5 runs, notes_app 137 runs green):

- The pure format: `OKF::Document` (render/parse), `Vocabulary`, `Template`,
  `TemplateAssociation`.
- The three seams: `Store` (Filesystem + Memory), `Index` (derived, in-memory,
  rebuildable from the store — also resolves collection membership), and
  `Repository` (the deep facade above).
- The engine foundation: `OKF::Container`, `OKF::Engine`, configuration.

Deliberately NOT done — these are waiting on your feedback:

- An ActiveRecord-backed `OKF::Index`. The default index is in-memory and
  rebuilt per container; it does not model app-global tags well (tags currently
  live inside one container's index). This is exactly where your "tags are
  global app-wide" requirement bites — so the AR index schema is the first thing
  your integration should pressure-test.
- The web layer (controllers, routes `/n` `/tags` `/templates` `/vocabulary`,
  the Tiptap/JST editor, CSS). It's being ported against notes_app as the live
  host. If agent_app needs UI, say so — it may pull that port forward.
- The collection-per-node wiring for your hierarchy. The pieces exist
  (`Index#members`, `containing_collections`, nested collections) but the
  node→collection mapping is host code you'll write — and a good source of
  feedback on whether the seam is right.

## What to bring back (the feedback that matters)

1. Tags global across nodes: does the per-container index force you into
   awkward workarounds? What would the AR-backed, app-global index need to look
   like for agent_app?
2. The node→collection mapping for descendant bundling: is
   `containing_collections` / `Index#members` enough, or does the library need a
   richer scope abstraction?
3. uuid-as-identity across nodes: does anything assume a note belongs to exactly
   one container? Moving a note between nodes should rewrite no files.
4. Storage: is per-container filesystem right for you, or do you want one shared
   store with a path strategy? Try `store_builder` and report what's missing.
5. Anything in the `Repository` facade you reached past — if you needed `Store`
   or `Index` directly, that's a sign the facade has a gap.

Read `ARCHITECTURE.md` in notes_app for the full design rationale and `SPEC.md`
for the format itself. Then integrate the data layer, keep notes flowing through
`node.okf.*`, and write down where it fought you.
