# OKF/HTML Conformance Fixtures

These fixtures are language-neutral test vectors, hand-written from the rules
in `SPEC.md` and executed against the Ruby reference implementation
(`okf-html`) to confirm the expected output. They are enforced by
`okf-html/test/conformance_fixtures_test.rb`, which loads every case here and
runs it through the real `OKF::Document`/`OKF::Index` API — so this directory
is not a static description of the Ruby tests, it is a conformance suite in
its own right, and a case added here adds coverage there automatically. These
files are for implementers who want to bring up a Python, JS, Go, Rust, or
other port without reading Ruby first.

## Files

- `render.yml` — input note attribute bags and the exact full HTML document a
  conforming renderer should emit.
- `parse.yml` — stored HTML documents and the expected parsed attributes. Each
  case has a `document` block for `OKF::Document.parse`-level fields and, when
  relevant, an `index` block for graph facts the reference index derives from the
  body.

## Rules

- Compare rendered HTML as an exact string, including final newline.
- Times are ISO8601 UTC strings. A port may parse them into native time values,
  but serialized comparisons should use the same strings.
- `title` is the explicit `<title>` value. `effective_title` is the display title
  derived by the note model or index: explicit title, else the first non-blank
  body block, else `Untitled`.
- `links` are document-level head links. Body links are exposed in
  `index.outgoing_links`; list-member body links also appear in
  `index.member_hrefs` in document order.
- `rev_links` in render input model already-derived backlinks. Implementations
  should normally create them through their Repository/reconciler, not by asking
  users to hand-author `<link rev>`.
- Associations mirror `OKF::TemplateAssociation#to_h` and serialize as
  `<link rel="okf:...">` in the head.

The initial set intentionally covers the stable core: identity, timestamps, tags,
custom metadata, head links, pinned/template flags, template association links,
`rev` mirrors, `title` vs `effective_title`, and collection/member parsing.
