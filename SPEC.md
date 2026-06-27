# OKF/HTML — Open Knowledge in plain HTML

Status: Draft · Version: 0.1 · Date: 2026-06-23

> Working title. This is an alternative to Google's Open Knowledge Format (OKF)
> that defines knowledge representation entirely in terms of native HTML, rather
> than inventing a new container of Markdown + YAML. The thesis: the web
> platform already is a knowledge format. Links are the knowledge graph;
> `<meta>`/`<link>` are the metadata; the DOM is the query model; every
> device ships a renderer. We add no new file types and no semantic-web
> toolchain (no RDF/OWL/SPARQL) — modern readers, human and machine, infer
> structure from HTML directly.
>
> See the companion post: *"OKF is just HTML with extra steps."*

---

## 1. Design principles

1. Everything is a note. A note is a complete, self-describing HTML
   document. The vocabulary, templates, collections, help, and this spec's own
   schema are *also* notes. The system is self-hosting — to extend it you
   author documents *in* it, not config beside it.
2. The link graph is the knowledge graph. Knowledge is expressed as typed
   edges between documents, using `<a>`, `<link>`, and `<meta>`.
3. Maximise native HTML. Prefer existing HTML, including link types HTML5
   dropped from its own list but which remain valid. Browsers may ignore them;
   conforming tools MUST NOT.
4. Name the relationship, never the position. A relation describes a
   *role or real-world relationship* (`chapter`, `author`, `bibliography`),
   never a *position in an anonymous container* (`first`, `last`, `up`,
   `start`, `end`). See §6.1.
5. Files are truth and index. The on-disk document is canonical. Any
   database is a derived cache that can be rebuilt from the files. Each file
   carries enough of its own graph (including inbound edges, §7) to be a
   complete, portable, queryable node offline.
6. One authority per fact; mirror the inverse. Each edge has an
   authoritative endpoint (the outbound `<a>` the author wrote). The
   inbound edge (`rev`) is a *maintained mirror*. On conflict, the authority
   wins and the reconciler repairs the mirror (§10).
7. Port proven models, not their machinery. Relationship semantics are
   ported from Rails associations (§9). The *declarative* layer is adopted;
   lifecycle machinery (callbacks, STI, autosave, validations) is not.

---

## 2. Notes are HTML documents

A note is a complete, valid HTML document — `<!DOCTYPE html>`, `<html>`,
`<head>`, `<body>`. Note-like systems (wikis, papers, journals, knowledge bases)
can be built on this spec; *note* is the domain concept (the thing a user
creates), and the HTML document is its concrete form.

> Terminology. *Note* and *HTML document* (or just *document*) are
> interchangeable in this spec. From here on we mostly say *HTML document* when
> describing mechanism, and *note* when describing the user-facing thing.

The `<body>` may contain anything valid in HTML — prose, headings, media,
tables, forms, `<script>`, `<style>`, custom elements, whatever. It is HTML; use
it exactly as you would use HTML. This spec puts no constraints on body
content; it governs only the `<head>` metadata and the links that connect
documents.

The `<head>` may likewise contain any valid HTML. For the purposes of this
spec, `<title>`, `<meta>`, and `<link>` describe the document and link it to
other documents — giving each file its own identity without a database.

```html
<!DOCTYPE html>
<html lang="en">
<head profile="https://br3nt.github.io/okf/">
  <meta charset="utf-8">
  <title>Sourdough Starter</title>
  <link rel="canonical" href="/n/sourdough-starter">
  <meta name="uuid"    scheme="UUID"    content="…">
  <meta name="created" scheme="ISO8601" content="2026-06-18T10:00:00Z">
  <meta name="updated" scheme="ISO8601" content="2026-06-18T12:00:00Z">
  <meta name="keywords" content="baking, bread">
</head>
<body>
  <h1>Sourdough Starter</h1>
  …
</body>
</html>
```

### 2.1 Identity

- `uuid` (a `<meta>` typed with the `UUID` scheme) — stable global identity that
  survives renames. Edges SHOULD be resolvable to a uuid.
- `canonical` (a `<link>` with the `canonical` relation) — the current address (`/n/<slug>`).
- slug — a human-readable address derived from the title/first heading.
  Renames mint a redirect from the old slug (reference impl: `SlugRedirect`).
- Optionally `itemid` (microdata) MAY carry the uuid as a graph node id.

### 2.2 The `<head>` profile declaration

Every note declares the vocabularies in force via the `profile` attribute on `<head>`, a
space-separated list of profile URIs (§6). This is how a note states *"these
`rel` values mean what these specs say."* Multiple profiles compose: a built-in
base profile plus user-defined profiles.

---

## 3. Metadata

Non-link metadata is expressed as `<meta>` elements. Although the `scheme`
attribute was part of HTML4 and dropped in HTML5, we have resurrected it for its
ability to give cohesive semantics to groups of metadata:

```html
<meta name="created"    scheme="ISO8601" content="2026-06-18T10:00:00Z">
<meta name="identifier" scheme="DOI"     content="10.1234/abcd">
```

Custom fields are user-extensible: any `name` is permitted. Known names
(`uuid`, `created`, `updated`, `keywords`, `pinned`, `author`) get typed
handling; unknown names are treated as strings.

To make a set of names self-describing, declare the vocabulary it belongs to
with a schema link — a `<link>` whose relation is `schema.PREFIX` — then use
`PREFIX.name`. Some useful vocabularies, each declared then used:

Dublin Core — bibliographic metadata on papers:

```html
<link rel="schema.DC" href="http://purl.org/dc/elements/1.1/">
<meta name="DC.creator" content="Jane Doe">
<meta name="DC.date"    content="2026-06-18">
```

schema.org — rich entity types, in its native JSON-LD idiom:

```html
<script type="application/ld+json">
{ "@context": "https://schema.org", "@type": "ScholarlyArticle",
  "name": "On Knowledge in Plain HTML", "author": "Jane Doe" }
</script>
```

Open Graph — social/preview metadata, using `property=` rather than a schema
link:

```html
<meta property="og:title" content="On Knowledge in Plain HTML">
<meta property="og:type"  content="article">
```

Your own profile's names (§6) — for app-specific fields, declared in the
profile that `<head>` points at.

---

## 4. The link graph

Edges to other documents are defined by `<a>` (visible, in
`<body>`) or `<link>` (invisible, in `<head>`). The same `rel` keyword is
valid in both places. An edge MAY also assert its inverse with `rev` (§7).

Attributes that qualify an edge: `title` (human label), `hreflang`, `type`
(MIME), `media`, `download`.

A head `<link>` is the place for a document-level relationship you do not want
sitting inline in the prose — a paper pointing at its `bibliography` note, an
`author`, a `license` — as well as the standard resource relations HTML already
defines: `icon`, `alternate`, `help`, `license`, `pingback`, `search`,
`stylesheet`, `canonical`. The same naming rule (§6.1) applies.

The reference implementation already derives the graph by parsing
`<a>` links to `/n/…` into link rows and links to `/tags/…` into tags.

---

## 5. Body-level semantics

Notes can make use of HTML's native semantic and citation elements:

- `<nav>` for tables of contents and pagers.
- `<ol>`/`<ul>` for ordered/unordered collection membership (§8).
- `<cite>` for work titles; `<blockquote>` / `<q>` for sourced quotes.
- `<ins>` / `<del>` for sourced, timestamped edits.
- `<dfn>` for the defining instance of a term; `<dl>` for glossaries.
- `<time>` for machine-readable dates; `<address>` for authorship.
- `<abbr>` for acronym expansion.
- `<a>` with the `bookmark` relation for section permalinks; text-fragment directives
  (`#:~:text=…`) for quoting into prose.

---

## 6. Vocabulary (the edge schema)

A profile is an HTML document that defines the `rel` terms it governs. Each
term is a `<dfn>` carrying: id/label, inverse, target-type,
cardinality, and a human description. Tools read this to drive
autocomplete and validation. The vocabulary is itself an HTML document
(self-hosting).

### 6.1 The naming rule

- Discouraged (positional, container implicit): `first`, `last`, `up`,
  `start`, `end`, `next`, `prev`. Avoid them — they describe a position in an
  *unnamed* container ("first of what? up to where?"), so their intent is vague
  and careless. A conforming editor SHOULD warn when one is used and offer a
  named alternative. They are not banned: where the sequence is genuine and
  named (e.g. the slides of a deck), `first`/`last` can be meaningful — but even
  then, prefer naming the collection and deriving order from it (below).
- Preferred form: names with semantic meaning — describe the *role or
  relationship* the target plays. By context, for example:
  - papers / references — `author`, `bibliography`, `cite-as`, `glossary`, `appendix`
  - books / guides — `chapter`, `section`, `subsection`, `contents`
  - people — `colleague`, `friend`, `muse` (and other XFN terms)
  - knowledge / data — `related`, `describedby`, `collection`, `item`
- Ordering: within a named collection (introduced in §8), the order of its
  members is defined with an `<ol>` rather than positional rels on the members;
  "next/prev" are then *derived* by walking the list (§8).

### 6.2 Base relation catalogue

HTML5 dropped most of HTML4's *structural* link types (`chapter`, `contents`,
`glossary`, `appendix`, …), and what it kept leans on vague positional words
(`next`/`prev`, §6.1). We revive the dropped HTML4 nouns on purpose: they
carry meaning where the replacements are too abstract — `chapter` says what the
target *is*; `next` only says where it sits. Browsers ignore the revived terms;
conforming tools honour them.

The built-in base profile:

- Revived HTML4 (structural): `contents`, `index`, `chapter`, `section`,
  `subsection`, `appendix`, `glossary`, `copyright`.
- Living HTML5: `alternate`, `author`, `bookmark`, `canonical`, `license`,
  `help`, `search`, `tag`, `external`, `nofollow`.
- IANA Web Linking: `collection`, `item`, `related`, `describedby`,
  `describes`, `cite-as`, `version-history`, `predecessor-version`,
  `successor-version`, `latest-version`.

### 6.3 Example profiles

Beyond the base, declare any external vocabulary as a profile (§2.2) or schema
link (§3) and compose it in — for example XFN for people relationships,
Dublin Core for bibliographic metadata, or schema.org for rich entity
types — or define your own profile for app-specific terms.

---

## 7. Inverse edges (`rev`)

`rel="X"` on a link in A's body asserts the edge A --X--> B. The mirror
recorded on B uses the same keyword with `rev` (standard HTML semantics):
`rev="X"` on B means "B is linked from A via X", i.e. the exact same edge
recorded at the target — so a file knows who links to it without the app's
database.

```html
<!-- A = /n/cookbook links to B = /n/pancakes -->
<a rel="recipe" href="/n/pancakes">Pancakes</a>

<!-- the mirror materialised in B's <head> -->
<link rev="recipe" href="/n/cookbook">
```

Only typed links (those with a `rel`) are mirrored — an untyped link has no
keyword to carry. A relation's human-facing *inverse name* (`chapter` ↔
`contents`, `has-many` ↔ `belongs-to`) is a separate concern of the vocabulary
and association layers (§6, §9), used for presentation and the generated UI; the
raw mirror always reuses the authoritative keyword.

- The outbound `<a>` is authoritative; `rev` is the maintained
  mirror. (Rails' `inverse_of`, §9.)
- Mirrors are maintained incrementally at write time (bounded:
  `O(edges changed)`), repaired by the reconciler (§10) on bootstrap,
  crash, or out-of-band edits.
- `rev` is valid HTML4 (dropped by HTML5) and remains live in RDFa. Conforming
  tools maintain it; browsers ignore it.

---

## 8. Collections

A collection is a first-class, named note that *owns* its membership as an
`<ol>` (ordered) or `<ul>` (unordered). Members declare role + membership; the
collection declares order.

```html
<!-- /n/cookbook -->
<article>
  <h1>Weeknight Cookbook</h1>
  <ol>
    <li><a rel="recipe" href="/n/pancakes">Pancakes</a></li>
    <li><a rel="recipe" href="/n/waffles">Waffles</a></li>
  </ol>
</article>

<!-- /n/pancakes — the materialised mirror (SPEC §7) -->
<link rev="recipe" href="/n/cookbook">
```

- Membership is an edge, not a location. A file lives in one directory (its
  physical bundle) but MAY belong to many collections (logical overlays). No
  copying.
- Typed collections: prefer a meaningful membership noun (`chapter`,
  `figure`, `recipe`); fall back to generic `item` only when none fits.
- Nesting: a collection MAY be an `item`/member of another (a book in a
  series).
- Identity: a collection carries a `uuid`, so members survive its rename.
- Tags are the degenerate case: unordered, flat, anonymous membership
  (`rel="tag"`), with a generated per-tag page. Collections are "tags that are
  documents, can impose order, and carry metadata."

---

## 9. Templates and associations (the node schema)

A template is a note used as a prototype. It defines a node's *shape*
(`<head>` and `<body>`) and, optionally, its *associations* to other
node types. Templates are notes; any note can be marked a template
(a `template` `<meta>` flag or membership in the Templates collection).

### 9.1 The `<template>` element and fillable fields

The prototype body lives in a `<template>` element (inert until cloned).
Fillable regions are `<slot>` or `data-field`; their prompts are ghost
text via `data-placeholder`/`data-hint`.

```html
<!-- /templates/person -->
<template>
  <article class="h-card">
    <h1 class="p-name"><slot name="name" data-placeholder="Full name"></slot></h1>
    <a class="u-email" data-field="email" href="">…</a>
  </article>
</template>
```

The `<head>` is half the template — it declares which `<meta>` fields and
`rel`s an instance ships with (e.g. a `chapter` template pre-wires
`rel="chapter" rev="contents"`).

### 9.2 Associations (ported from Rails)

Templates declare relationships to *other templates* in the head, so the UI to
add related notes is generated, not hand-built.

| Rails | OKF declaration | Semantics |
|---|---|---|
| `belongs_to` | `okf:belongs-to` | authoritative side, one, holds the edge |
| `has_many` | `okf:has-many` | inverse/derived side, or the `<ol>` |
| `has_one` | `okf:has-one` | inverse, one |
| `inverse_of` | `data-inverse` | the `rel`↔`rev` pairing (§7) |
| `dependent:` | `data-dependent` | `destroy` / `nullify` / `restrict` (§10) |
| `through` | `data-through` | join note carrying per-edge metadata (§9.3) |
| HABTM | both ends declare `has-many` | many-to-many, no metadata |
| polymorphic | `data-polymorphic` | open/union target-type |
| `optional:` | `data-optional` | required vs optional field |
| `counter_cache` | `data-counter` | cached count badge |
| order scope | `data-ordered` | the collection `<ol>` |

```html
<!-- /templates/book -->
<link rel="okf:has-many" href="/templates/chapter"
      data-as="chapter" data-inverse="belongs-to"
      data-dependent="destroy" data-ordered="true">

<!-- /templates/chapter -->
<link rel="okf:belongs-to" href="/templates/book"
      data-as="chapter" data-inverse="has-many" data-optional="false">
```

Not ported: callbacks, STI, autosave, validation lifecycles. The schema is
declarative data-model only.

### 9.3 Join notes

When an edge has its own attributes (a chapter's position, a reading-list
entry's date-added, a citation's page range), the edge becomes a node: a join
note (Rails `has_many :through`). It `belongs-to` both endpoints and carries
the membership metadata as `<meta>`.

---

## 10. The reconciler (execution)

The reconciler holds no policy of its own; it is a pure interpreter of the
schema (§6, §9). Given the rules, it:

- Materialises `rev` mirrors from authoritative `<a>` edges.
- Cascades deletes per `data-dependent`: `destroy` (delete dependents),
  `nullify` (drop the edge, keep the node), `restrict` (refuse while dependents
  exist).
- Maintains order in collection `<ol>`s.
- Repairs drift between authority and mirror; authority wins.

Execution modes:

- Incremental — ordinary edits, bounded `O(edges changed)`, synchronous.
- Batched / streamed / resumable — bulk rename/merge/delete of high-degree
  nodes (write amplification), with progress (`updated / remaining`) streamed to
  the UI.
- Full reconcile — bootstrap, crash recovery, import of an out-of-band
  folder. This is the repair tool, not the hot path. (Reference impl:
  `Note.rebuild_index_for`.)

---

## 11. UI requirements (conforming editor)

1. Relationship picker — on creating/editing an `<a>`, a relationship field:
   autocomplete from the active profile vocabulary (nouns), freeform with
   define-on-first-use (prompt for label/inverse/target-type/description),
   an "and the reverse?" `rev` toggle, an inline rel badge on existing links,
   and a warning on discouraged positional words (§6.1).
2. Properties panel — custom metadata as rows: `name` (autocomplete incl.
   `DC.*`), `value`, optional `scheme`. Fully extensible.
3. Generated relationship UI — template associations (§9.2) drive "Add
   chapter" affordances (`has_many` → nested forms), `belongs_to` pickers, and
   join-note editors. No bespoke per-type UI.
4. Fillable scaffolding is ephemeral; semantic markup is permanent. On
   completion, strip `data-placeholder`/`data-hint`/empty slots; keep classes,
   `rel`s, and `<time>`. A completeness checklist is derived from the template's
   declared fields.

---

## 12. Conformance

- Reader — parses notes, resolves edges by uuid/canonical, honours dropped
  HTML4 rels and `rev`.
- Writer/Editor — additionally surfaces the naming-rule warnings (§6.1),
  define-on-first-use, and the ephemeral-scaffolding rule (§11.4).
- Reconciler — additionally maintains `rev`, `dependent:` cascades, and
  collection order.

---

## 13. Reference implementation

This repository (`notes_app`, Rails) is the reference implementation. Existing
mapping:

| Spec concept | Reference impl |
|---|---|
| Note as HTML document | `NoteDocument#render` / `#parse` |
| Files are truth | `NoteStore` (`storage/knowledge/<user>/<slug>.html`) |
| Derived index, rebuildable | `Note.rebuild_index_for`, FTS5 |
| Link graph | `NoteLink`, `outgoing_links`/`incoming_links` |
| Tags from `<a>` links to `/tags/…` | `Tag`, `NoteTag`, `Note#sync_tags` |
| Rename redirects | `SlugRedirect`, `Note#generate_slug` |
| Portable raw document | `notes#document` route (`file://`-openable) |

To build out: `<head>` profiles + vocabulary notes, `rev` materialisation,
collections, templates + associations, join notes, the reconciler's
`dependent:`/order rules, and the UI surfaces (§11).

---

## 14. Roadmap

- Headless API / embeddable core — the spec's engine (parse, render,
  link-graph, reconciler) as a headless implementation embeddable in any
  application, with any app able to host multiple headless implementations.
  Tracked as a GitHub issue.

---

## Appendix A — Worked examples / common mental models

Short sketches showing how everyday systems fall out of the primitives above.
Each uses meaningful noun rels (§6.1) and derives order from lists, not
positional words.

### A simple note-taking system

A note is just an HTML document with prose and links. Untyped links are mere
references; a typed link asserts a relationship.

```html
<h1>Groceries</h1>
<p>Buy oat milk; see <a rel="related" href="/n/pantry-stock">pantry stock</a>.</p>
```

### A Zettelkasten

Atomic notes, each one idea, connected by `related` (peer ideas) and
`describedby` (a note explained by another). Structure emerges from the links,
not from folders.

```html
<h1>Compounding</h1>
<p>Small gains accrue. <a rel="related" href="/n/habits">Habits</a>.</p>
<link rel="describedby" href="/n/interest-maths">
```

### A journal

Dated entries as `h-entry` microformat notes, gathered by a journal collection.
`<time>` carries the machine-readable date.

```html
<article class="h-entry">
  <h1 class="p-name">2026-06-18</h1>
  <time class="dt-published" datetime="2026-06-18">Thursday</time>
  <div class="e-content"><p>Shipped the collections pager.</p></div>
</article>
```

### Todos

A todo is a note; a list owns the todos in an `<ol>`. Completion is metadata on
the item, not a separate type.

```html
<ol>
  <li><a rel="task" href="/n/water-plants">Water plants</a></li>
  <li><a rel="task" href="/n/call-dentist">Call dentist</a></li>
</ol>
```

### A list of quotes

Sourced quotations with `<blockquote>` (carrying a `cite`) and an `h-cite` for
the work.

```html
<blockquote cite="/n/walden">
  <p>I went to the woods because I wished to live deliberately.</p>
  <cite class="h-cite"><a rel="cite-as" href="/n/walden">Walden</a></cite>
</blockquote>
```

### A book

A book is a collection whose chapter order lives in an `<ol>`; the supporting
matter uses revived HTML4 structural rels (§6.2).

```html
<h1>The Sea</h1>
<ol>
  <li><a rel="chapter" href="/n/tides">Tides</a></li>
  <li><a rel="chapter" href="/n/currents">Currents</a></li>
</ol>
<link rel="contents"     href="/n/the-sea-toc">
<link rel="appendix"     href="/n/measurements">
<link rel="bibliography" href="/n/sources">
<link rel="glossary"     href="/n/terms">
<link rel="index"        href="/n/the-sea-index">
```

### A slide deck

A deck is a genuine, named sequence, so `first`/`last` are acceptable here (§6.1)
— but order still derives from the `<ol>`; the positional rels are convenience
pointers, not the source of truth.

```html
<h1>Intro to OKF</h1>
<ol>
  <li><a rel="slide" href="/n/slide-title">Title</a></li>
  <li><a rel="slide" href="/n/slide-thesis">Thesis</a></li>
  <li><a rel="slide" href="/n/slide-demo">Demo</a></li>
</ol>
<link rel="first" href="/n/slide-title">
<link rel="last"  href="/n/slide-demo">
```
