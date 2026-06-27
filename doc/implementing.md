# Implementing OKF/HTML in any language or framework

OKF is portable by construction. It defines no new file type and no sidecar
format — a note is an HTML document, and the conventions live *in* the HTML. Any
language with an HTML parser can implement it, and any web framework can serve it.
This guide is the starting point for a port; the normative source is `SPEC.md`.

Status: the Ruby reference implementation (`okf-html` + `okf-html-rails`) exists;
ports to other languages and a shared conformance suite do not yet. Contributions
welcome — see the "official implementations + conformance suite" issue.

## The shape of an implementation

The reference factors into four narrow pieces. A port in any language mirrors
them; the names matter less than the seams.

- **Document** — render a note's attributes to a full HTML document, and parse one
  back. The head carries identity, timestamps, tags, metadata and links; the body
  is the editable content. This is the only piece that touches the serialization.
- **Store** — dumb byte storage keyed by uuid (`read` / `write` / `delete` /
  `each_key`). Filesystem is the default and the file is truth (§1).
- **Index** — a derived, rebuildable view over the store: resolve, search,
  backlinks, tagged, members. Never truth; rebuildable from the store.
- **Repository** — the deep facade: create / find / update / delete / list /
  search / reconcile. It owns identity, slugs, rendering, rev-mirror
  materialisation and dependent-delete, so callers never assemble HTML.

## Conformance checklist

An implementation conforms to OKF/HTML 0.1 if it:

- Assigns a stable **uuid** per note and treats `/n/<uuid>` as the canonical link,
  with `/n/<slug>` resolving to it (§ identity). uuid survives renames and moves.
- Stores each note as a **complete, self-describing HTML document** (§1) and
  treats the stored document as truth.
- Carries `created`/`updated` as **ISO8601** `<meta>` and the title in `<title>`,
  deriving `effective_title` (explicit title → first line → "Untitled").
- Expresses edges as **typed links** (`<a rel="…" href="/n/…">`) and materialises
  the **inverse as a rev mirror** on the target (§6 vocabulary, §7 mirrors).
- Warns on **positional rel names** (`next`, `prev`, `first`, …) without rejecting
  them (§6.1), and derives sequence by walking a collection's list rather than
  from positional links.
- Models **collections** as documents whose list items link members, with nesting
  giving transitive membership (§8).
- Supports **templates** and associations via `<template>` and
  `<link rel="okf:…">` (§9).
- Applies **dependent-delete** policies and repairs the graph on **reconcile**
  (§10): restrict / destroy / nullify.
- Serves its own UI as **hypermedia, not JSON** (see `doc/hypermedia.md`).

## Targets

- Languages: JavaScript/TypeScript (Node + browser), Python, Go, Rust, PHP,
  Elixir, Java/Kotlin.
- Frameworks: Rails (done — `okf-html-rails`), Sinatra/Hanami, Django/Flask,
  Laravel, Phoenix, Express/Hono/Next, Spring.

The web platform already ships a renderer everywhere, so a conforming store of
`.html` files is usable from any of these without a runtime in common — that is
the portability payoff.

## A shared conformance suite (wanted)

To prove a port conforms, we want a language-neutral fixture set: input attribute
bags → expected rendered HTML, stored HTML → expected parsed attributes, and
graph/reconciler scenarios → expected end state. A port passes by driving its
Document/Repository against the fixtures. Tracked in the conformance issue.
