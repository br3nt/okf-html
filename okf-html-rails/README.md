# okf-html-rails

A mountable Rails engine that embeds [OKF/HTML](https://br3nt.github.io/okf/)
notes in a host application. It wires the pure [`okf-html`](../okf-html) core into
Rails so a host gets notes, links, tags, collections, templates and the
reconciler by including one concern and (optionally) mounting one engine.

## Install

```ruby
# Gemfile
gem "okf-html-rails", git: "https://github.com/br3nt/okf-html"
```

## Give a model notes

Include the container concern in whatever owns notes — a user, a workspace node,
anything:

```ruby
class Workspace < ApplicationRecord
  include OKF::Container
end

workspace.okf.create(title: "Idea", content: "<p>…</p>")
workspace.okf.find(uuid)
workspace.okf.search("idea")
workspace.okf.update(uuid, title: "Better idea")
workspace.okf.delete(uuid, dependent: :nullify)
```

Each container gets its own filesystem store, namespaced by class and id, with a
derived index over it. The files are the truth (SPEC §1).

## Configure

```ruby
# config/initializers/okf.rb
OKF.configure do |c|
  c.store_root = Rails.root.join("storage/okf")
  # Or take over storage entirely (e.g. one datastore for all containers):
  # c.store_builder = ->(container) { MyStore.new(container) }
end
```

You usually don't need to set `store_root` at all. The default is
`Rails.root.join("storage/okf", Rails.env)` — segmented by environment so dev,
test and production never share files. If you set it yourself, include the
environment (or another per-environment discriminator) so your environments stay
isolated.

## Mount (controllers + editor UI)

```ruby
# config/routes.rb
mount OKF::Rails::Engine => "/okf"
```

The engine isolates the `OKF` namespace. Configuration and the container
association ship now; the controllers, routes and the JST/Tiptap editor are being
ported from the reference application (notes_app) and land in a following phase.

## Build with hypermedia, not JSON

OKF is HTML all the way down — including over the wire. Serve notes, lists of
notes, and the vocabulary as HTML (a list of notes is a collection §8, which is
already an HTML document); use Turbo for mutations and live updates; reach for
JSON only at a deliberate external API seam, behind content negotiation. The
patterns — index-as-collection, autocomplete-as-fragment, vocabulary-as-markup —
are written up in [`doc/hypermedia.md`](../doc/hypermedia.md). When the editor is
packaged, its lists ship as HTML fragments, not a `*.json` API.

## Status

Tracks the spec version (spec 0.1 → gem 0.1.x). Not on RubyGems yet.
