# Hypermedia, not JSON — the OKF way to build on this

OKF/HTML's thesis is that HTML *is* the knowledge format. The same thesis applies
over the wire. The canonical representation of a note, of a list of notes, and of
the vocabulary is HTML — hypermedia a browser already knows how to render and a
client already knows how to follow. Reach for JSON only at a deliberate, external
seam (a documented data API for third-party machine consumers). For your own
application's UI, don't introduce JSON at all.

This is not a style preference. A note is already hypermedia: its links are the
graph. A *list* of notes is already a first-class OKF object: a collection (§8),
an HTML document whose body is a list of `<a href="/n/…">` links. So "give me all
the notes" does not need a new JSON contract — it has a native HTML
representation. Serving it as JSON discards the format's whole premise and leaves
you maintaining a second, parallel shape of the same data.

> Rule of thumb: if the data you're about to serialise to JSON is a note, a list
> of notes, or links between notes, you already have an HTML representation for it.
> Use that.

## The patterns ("this is the way")

### "All notes" / an index → a collection document

Render an HTML list of links, not a JSON array. This *is* a collection (§8), so it
also composes with membership and ordering for free.

```html
<!-- GET /n  →  text/html -->
<ul class="okf-notes">
  <li><a href="/n/routing">Routing</a></li>
  <li><a href="/n/controllers">Controllers</a></li>
</ul>
```

The client follows links; there is no out-of-band contract to agree on. Paginate
with a "more" link (navigation, not a knowledge edge — see §6.1 on not encoding
position as a `rel`), or HTTP `Link` headers.

### Wikilink autocomplete → an HTML fragment, not `/n.json`

The editor needs candidate notes. Serve a fragment and let the editor read it (or
let JST render the dropdown from it):

```html
<!-- GET /n?q=rou  →  text/html (a fragment) -->
<ul>
  <li><a href="/n/routing">Routing</a></li>
  <li><a href="/n/router-config">Router config</a></li>
</ul>
```

Tiptap (or any editor) parses that fragment into its suggestion list exactly as
easily as it parses a JSON array — and you keep one representation, not two.

### Vocabulary → markup, not `/vocabulary.json`

Serve the rel catalogue as HTML the picker reads from the DOM (inverse as a data
attribute), or a native `<datalist>`:

```html
<datalist id="okf-rels">
  <option value="chapter" data-inverse="chapter-of">
  <option value="author"  data-inverse="authored">
</datalist>
```

### Create / update → form in, rendered note out

POST/PATCH form-encoded; the response body is the rendered note's HTML. Turbo
swaps it into place. The note's document *is* the response — no JSON envelope.

### Live updates → Turbo Streams of rendered HTML

Broadcast the note's rendered HTML to subscribers on write (see the concurrent-
editing issue). The wire format stays HTML end to end.

## Where JST fits

JST (client-side templating) is for the interactive bits that aren't a full-page
navigation — rendering the autocomplete dropdown, building inline link/tag chips.
It consumes server-sent HTML fragments; it does not justify a JSON API. If you
find JST rendering from JSON, that's the smell — feed it the fragment instead.

## When JSON is actually fine

- A documented, versioned **external** API whose consumers are non-browser
  programs that explicitly want a data contract. Even then, prefer HTTP content
  negotiation (serve HTML by default, JSON on `Accept: application/json`) so the
  hypermedia representation stays primary.
- Never for your own front-end's note/list/graph rendering.

## Checklist

- [ ] No `*.json` endpoint backs a view you also render in HTML.
- [ ] "List of notes" is a collection document, not a JSON array.
- [ ] Editor lists (notes, vocabulary, tags) are HTML fragments.
- [ ] Mutations return the rendered note HTML; Turbo swaps it.
- [ ] JSON, if present at all, sits behind content negotiation at an external seam.
