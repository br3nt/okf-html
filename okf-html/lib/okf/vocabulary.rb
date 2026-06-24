module OKF
  # The OKF vocabulary in force (SPEC §6): which rel terms a document's links may
  # use, each term's inverse (for materialising rev mirrors, §7), and the
  # discouraged positional words the naming rule (§6.1) warns against.
  #
  # This is the built-in base profile. User-defined profiles (themselves HTML
  # documents, §6) will extend it; for now the catalogue lives here.
  class Vocabulary
    # SPEC §6.1 — positional words name a position in an anonymous container
    # rather than a relationship, so their intent is vague. A writer SHOULD warn,
    # but does not reject them (they can be meaningful for a genuine sequence).
    DISCOURAGED = %w[first last up start end next prev previous].freeze

    # SPEC §6.2 — the base relation catalogue, term => inverse term (nil if the
    # relation has no meaningful inverse). A self-inverse relation (related) maps
    # to itself.
    TERMS = {
      "chapter"     => "contents",
      "contents"    => "chapter",
      "section"     => "contents",
      "subsection"  => "section",
      "appendix"    => "contents",
      "glossary"    => nil,
      "index"       => nil,
      "collection"  => "item",
      "item"        => "collection",
      "related"     => "related",
      "describedby" => "describes",
      "describes"   => "describedby",
      "author"      => nil,
      "bibliography" => nil,
      "cite-as"     => nil,
      "license"     => nil,
      "help"        => nil,
      "tag"         => nil
    }.freeze

    # SPEC §3 — the built-in starter set of metadata schemes and the common field
    # names each scheme typically supplies. Surfaced to the Properties panel so a
    # writer who picks a scheme gets a narrowed name datalist (and need not know
    # the field names by heart). Curated, not exhaustive; user-defined profiles
    # may extend it later (§6).
    SCHEMES = [
      { scheme: "DC",      names: %w[DC.creator DC.subject DC.date DC.identifier DC.publisher DC.rights DC.language] },
      { scheme: "ISO8601", names: %w[created updated date] },
      { scheme: "DOI",     names: %w[identifier] },
      { scheme: "UUID",    names: %w[uuid] },
      { scheme: "Schema",  names: %w[name author datePublished] },
      { scheme: "OG",      names: %w[og:title og:description og:image] }
    ].freeze

    # SPEC §4 — common rel values for document-level head links (relationships not
    # inline in the prose). The vocabulary TERMS (chapter, bibliography, …) plus
    # the standard HTML resource relations. Surfaced to the Properties panel's
    # link mode as autocomplete.
    HEAD_LINK_RELS = (TERMS.keys + %w[icon alternate stylesheet pingback search]).uniq.freeze

    class << self
      def discouraged?(rel) = DISCOURAGED.include?(normalize(rel))
      def known?(rel)     = TERMS.key?(normalize(rel))
      def inverse(rel)    = TERMS[normalize(rel)]
      def terms           = TERMS.keys
      def schemes         = SCHEMES
      def head_link_rels  = HEAD_LINK_RELS

      private

      def normalize(rel) = rel.to_s.strip.downcase
    end
  end
end
