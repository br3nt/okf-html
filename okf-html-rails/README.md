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

## The workspace-global SQL index

The default index is in-memory and per-container. For cross-node features — a
node's subtree bundle, the app-wide tag namespace, cross-node search, and moving
notes between nodes — switch to the SQL-backed index:

```bash
bin/rails g okf:install   # migration (okf_notes/okf_edges/okf_taggings) + initializer
bin/rails db:migrate
```

```ruby
# config/initializers/okf.rb
OKF.configure do |c|
  c.index_builder = ->(_container) { OKF::Rails::Index.new }
  c.store_builder = ->(_container) { OKF::Store::Filesystem.new(root: c.store_root) }
end
```

Now queries take a scope — the container's own id by default, an id-set for a
node and its descendants (the host computes the set; the library never walks your
tree), or `:global`:

```ruby
node.okf.search("plan")                       # this node
node.okf.search("plan", scope: subtree_ids)   # node + descendants
node.okf.search("plan", scope: :global)       # whole workspace
node.okf.tagged("urgent", scope: :global)
node.okf.move(uuid, to: other_node.okf_namespace)   # re-home; identity + graph intact
```

The index conforms to the same interface as the in-memory one, so nothing above
the facade changes; the files stay truth and the index is rebuildable from them.

## The note editor (no-build engine asset)

The engine ships the Tiptap editor — toolbar, autosave, lists/checklists, note
links with a `rel` picker, and in-content `#tags` — plus the vendored
Tiptap/ProseMirror ESM, for importmap + propshaft hosts (no bundler).

```ruby
# config/routes.rb
mount OKF::Rails::Engine => "/okf"
```

```erb
<%# app/views/layouts/application.html.erb %>
<%= stylesheet_link_tag "okf/editor" %>
<%= javascript_importmap_tags %>
```

The engine's importmap pins (`okf/editor` + Tiptap/ProseMirror) are contributed to
your importmap automatically. Mount the editor on an element per note:

```js
import { mountEditor } from "okf/editor"

const el = document.querySelector(".okf-editor-mount") // data-note-uuid / data-initial-content
const handle = mountEditor(el, {
  content: el.dataset.initialContent,
  updateUrl: `/n/${el.dataset.noteUuid}`,   // PATCH target (form params, HTML back)
  wikilinksUrl: "/n/catalog",               // GET: HTML list of notes for [[wikilinks]]
  vocabularyUrl: "/vocabulary"              // GET: vocabulary as HTML for the rel picker
})
handle.getHTML() // the current body; handle.destroy() to tear down
```

Everything travels as HTML: the lists are parsed from markup and the autosave
PATCHes a form body (`note[content]`), expecting the rendered note HTML back — no
JSON. A host endpoint must accept the form PATCH and respond with HTML carrying a
`[data-slug]` (see notes_app's `notes/_saved` partial). The engine isolates the
`OKF` namespace; controllers/routes are still host-owned.

## Build with hypermedia, not JSON

OKF is HTML all the way down — including over the wire. There is no JSON: HTML is
the data contract. Serve notes, lists of notes, and the vocabulary as HTML (a list
of notes is a collection §8, which is already an HTML document); use Turbo for
mutations and live updates; a machine consumer parses the HTML. The patterns —
index-as-collection, autocomplete-as-fragment, vocabulary-as-markup — are written
up in [`doc/hypermedia.md`](../doc/hypermedia.md). The editor's lists ship as HTML
fragments, not a `*.json` API.

## Status

Tracks the spec version (spec 0.1 → gem 0.1.x). Not on RubyGems yet.
