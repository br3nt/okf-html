# Upgrading agent_app to okf-html 0.1.3

These releases add the workspace-global SQL index, `move()`, the packaged note
editor (0.1.1), the graph visualiser + filter language (0.1.2), and JST
components for declarative embedding (0.1.3). Here's how to adopt them. The one
hard rule throughout: everything over the wire is HTML, never JSON (see
`doc/hypermedia.md`).

If you use JST (v0.4.1+), you can skip the imperative mount calls below and embed
declaratively (hypertext as the API): render `<%= render "okf/components" %>`
once, then write `<okf-editor note-uuid=… update-url=… wikilinks-url=…
vocabulary-url=…>` and `<okf-graph graph-url=… filter=…>`. See the engine README,
"Embed declaratively with JST components". The imperative API below still works.

## 0. Pin v0.1.1

```ruby
# Gemfile
gem "okf-html",       git: "https://github.com/br3nt/okf-html", glob: "okf-html/*.gemspec",       tag: "v0.1.3"
gem "okf-html-rails", git: "https://github.com/br3nt/okf-html", glob: "okf-html-rails/*.gemspec", tag: "v0.1.3"
```

`bundle install`. Loading the gem registers the engine; its initializers add the
editor + Tiptap assets to your asset paths and the importmap pins to your
importmap automatically.

## 1. Swap the placeholder textarea for the packaged editor

In your layout:

```erb
<%= stylesheet_link_tag "okf/editor" %>
<%= javascript_importmap_tags %>
```

Mount per note (you already have the `.okf-editor-mount` points wired):

```js
import { mountEditor } from "okf/editor"   // or use window.OKF.mountEditor

const el = document.querySelector(".okf-editor-mount") // data-note-uuid, data-initial-content
const handle = window.OKF.mountEditor(el, {
  content:       el.dataset.initialContent,
  updateUrl:     `/your/notes/${el.dataset.noteUuid}`, // PATCH target
  wikilinksUrl:  "/your/notes/catalog",                // GET: HTML list of notes
  vocabularyUrl: "/your/vocabulary"                    // GET: vocabulary as HTML
})
handle.getHTML()   // current body; handle.destroy() to tear down
```

You get the toolbar, debounced autosave, bullet/task lists, `[[wikilink]]`
autocomplete, a `rel` picker, and in-content `#tags`. You do **not** need the
template properties/associations panels — just don't render those DOM blocks and
don't pass `templatesUrl`; they stay dormant.

## 2. Your endpoints speak HTML

- **`updateUrl`** accepts a form PATCH whose body is `note[content]=<html>` (plus
  `note[title]` if you render a title input). Respond with HTML containing a
  `[data-slug]` element so a rename propagates, e.g.
  `<div data-slug="<%= note.slug %>"></div>`. (notes_app's `notes/_saved` partial
  is the reference.) Do **not** return JSON.
- **`wikilinksUrl`** returns an HTML list — a collection (§8):
  `<ul><li><a href="/n/<slug>">Title</a></li>…</ul>`. The editor reads the anchor
  text as the title and the href as the slug.
- **`vocabularyUrl`** returns the vocabulary as HTML: `.vocab-terms li[data-rel][data-inverse]`,
  `.vocab-discouraged li`, `.vocab-schemes li[data-scheme][data-names]`,
  `.vocab-head-link-rels li`. (notes_app's `vocabulary/show.html.erb` is the
  reference.)

## 3. Adopt the workspace-global SQL index

```bash
bin/rails g okf:install   # okf_notes / okf_edges / okf_taggings + initializer
bin/rails db:migrate
```

```ruby
# config/initializers/okf.rb
OKF.configure do |c|
  c.index_builder = ->(_container) { OKF::Rails::Index.new }
  c.store_builder = ->(_container) { OKF::Store::Filesystem.new(root: c.store_root) }
end
```

Now queries take a scope. The container's `okf_namespace` is its scope id.

```ruby
node.okf.search("plan")                      # just this node
node.okf.search("plan", scope: subtree_ids)  # node + descendants — YOU compute the id-set
node.okf.search("plan", scope: :global)      # whole workspace
node.okf.tagged("urgent", scope: :global)    # app-wide tag namespace
node.okf.all(scope: subtree_ids)             # descendant bundle
node.okf.move(uuid, to: other_node.okf_namespace)  # re-home; identity + graph intact
```

For descendant bundling you compute the set of `okf_namespace` ids for a node and
its descendants (your tree, your traversal) and pass it as `scope:`. The library
never walks your tree — exactly the boundary you asked for.

## 4. Feed back

Report on issues #1 (index) and #6 (editor): anything missing for your node tree,
the editor mount, or the HTML endpoints — it drives the next patch.
