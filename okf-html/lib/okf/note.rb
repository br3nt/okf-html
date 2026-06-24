require "active_support/core_ext/object/blank"

module OKF
  # A plain value object carrying a note's attributes — the concrete thing the
  # pure Repository creates, finds and renders. It implements the interface
  # OKF::Document expects (uuid, slug, effective_title, timestamps, tag_names,
  # pinned?, content, …) with no persistence and no Rails. A host with its own
  # model (e.g. an ActiveRecord Note) can use that instead; this is the default.
  class Note
    ATTRIBUTES = %i[uuid slug title content created_at updated_at tag_names
                    pinned template template_uuid metadata links associations
                    incoming_links].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize(attrs = {})
      @tag_names = []
      @metadata = []
      @links = []
      @associations = []
      @incoming_links = []
      @pinned = false
      @template = false
      @content = ""
      assign(attrs)
    end

    # Merge a hash of attributes (string or symbol keys) onto this note.
    def assign(attrs)
      attrs.each { |key, value| public_send("#{key}=", value) if respond_to?("#{key}=") }
      self
    end

    def pinned?   = !!@pinned
    def template? = !!@template

    # The title shown to the user and written into the document's <title>. An
    # explicit title wins; otherwise the note names itself after its first
    # non-blank line of content; failing that it is Untitled.
    def effective_title
      title.presence || first_line || "Untitled"
    end

    # The text a slug is derived from: an explicit title, else the first line.
    # Unlike effective_title this is nil (not "Untitled") when the note is empty,
    # so the Repository can fall back to the uuid.
    def slug_source
      title.presence || first_line
    end

    # Build a Note from a parsed document (OKF::Document::Parsed), for rebuilding
    # an index or finding a note from the store.
    def self.from_parsed(parsed)
      new(
        uuid: parsed.uuid, slug: parsed.slug, title: parsed.title,
        content: parsed.body, created_at: parsed.created_at, updated_at: parsed.updated_at,
        tag_names: parsed.tag_names, pinned: parsed.pinned?, template: parsed.template?,
        template_uuid: parsed.template_uuid, metadata: parsed.metadata,
        links: parsed.links, associations: parsed.associations
      )
    end

    private

    # The first non-blank block element's text, else the first non-blank text
    # line — the "title for free" a real document gives us.
    def first_line
      return nil if content.blank?
      fragment = Nokogiri::HTML5.fragment(content)
      block = fragment.css("h1,h2,h3,h4,h5,h6,p,li,blockquote,pre,figcaption")
        .map { |el| el.text.strip }.find(&:present?)
      block || fragment.text.each_line.map(&:strip).find(&:present?)
    end
  end

  # An inbound edge the Repository hands to Document so it can render rev mirrors
  # (SPEC §7). Shaped to match what Document reads: +rel+ and +source_note.slug+.
  Backlink = Struct.new(:rel, :source_slug) do
    SourceRef = Struct.new(:slug)
    def source_note = SourceRef.new(source_slug)
  end
end
