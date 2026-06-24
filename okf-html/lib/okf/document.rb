module OKF
  # A note IS a complete, self-describing HTML document. Document is the bridge
  # between a note's attributes and that document: render() builds the full
  # <html> (head generated from metadata, body = the editable content), and
  # parse() reads the attributes back out of a document on disk.
  #
  # The body links and tags are already self-describing (<a href="/n/..."> and
  # <a rel="tag">); this class adds the note's own identity to its <head> so the
  # file knows its title, URI, timestamps and tags without any database. The note
  # is duck-typed: it responds to uuid, slug, effective_title, created_at,
  # updated_at, tag_names, pinned?, content, and optionally template?,
  # template_uuid, metadata, links, associations, incoming_links.
  class Document
    DOCTYPE = "<!DOCTYPE html>"
    # Surfaced on the class as well as the module so host code that references
    # them through the document (NoteDocument::PROFILE) keeps resolving.
    PROFILE = OKF::PROFILE
    CANONICAL_PREFIX = OKF::CANONICAL_PREFIX

    def self.render(note)
      new(note).render
    end

    def self.parse(html)
      Parsed.new(html)
    end

    def initialize(note)
      @note = note
    end

    def render
      lines = [
        DOCTYPE,
        %(<html lang="en">),
        %(<head profile="#{PROFILE}">),
        %(<meta charset="utf-8">),
        "<title>#{escape(@note.effective_title)}</title>",
        %(<link rel="canonical" href="#{escape(CANONICAL_PREFIX + @note.slug.to_s)}">),
        meta("uuid", @note.uuid, scheme: "UUID"),
        meta("created", iso(@note.created_at), scheme: "ISO8601"),
        meta("updated", iso(@note.updated_at), scheme: "ISO8601")
      ]
      tags = Array(@note.tag_names)
      lines << meta("keywords", tags.join(", ")) if tags.any?
      lines << meta("pinned", "true") if @note.pinned?
      lines << meta("template", "true") if @note.try(:template?)
      custom_metadata.each do |field|
        lines << meta(field["name"], field["value"], scheme: field["scheme"].presence)
      end
      # SPEC §4 — custom document-level head links (relationships not inline in the
      # prose: bibliography, license, icon, …).
      custom_links.each do |link|
        lines << %(<link rel="#{escape(link["rel"])}" href="#{escape(link["href"])}">)
      end
      # SPEC §9.2 — the instance's template associations, declared in the head so
      # they stay self-describing on disk (the editor strips them from the body).
      TemplateAssociation.from_column(@note).each { |assoc| lines << assoc.to_link }
      lines << meta("instance-of", @note.try(:template_uuid), scheme: "UUID") if @note.try(:template_uuid).present?
      lines.concat(reverse_links)
      lines.concat([ "</head>", "<body>", @note.content.to_s, "</body>", "</html>" ])
      lines.compact.join("\n") + "\n"
    end

    private

    # SPEC §7 — materialise the inbound edges as rev mirrors, derived from the
    # link graph: for each typed link source --rel--> me, emit <link rev="rel">.
    # Untyped links have no keyword to mirror and are skipped. Sorted for a
    # stable, diff-friendly document.
    def reverse_links
      Array(@note.try(:incoming_links)).filter_map { |link|
        rel = link.rel.to_s
        source_slug = link.source_note&.slug
        next if rel.empty? || source_slug.blank?
        %(<link rev="#{escape(rel)}" href="#{escape(CANONICAL_PREFIX + source_slug)}">)
      }.sort
    end

    # Custom <meta> fields beyond the reserved names, normalised to string keys
    # (SPEC §3). Accepts symbol- or string-keyed hashes.
    def custom_metadata
      Array(@note.try(:metadata)).filter_map { |field|
        next unless field
        name = field["name"] || field[:name]
        next if name.blank?
        { "name" => name.to_s, "value" => (field["value"] || field[:value]).to_s,
          "scheme" => (field["scheme"] || field[:scheme]).to_s }
      }
    end

    # Custom head links beyond the generated ones, normalised to string keys
    # (SPEC §4). Each is { "rel", "href" }.
    def custom_links
      Array(@note.try(:links)).filter_map { |link|
        next unless link
        rel = link["rel"] || link[:rel]
        href = link["href"] || link[:href]
        next if rel.blank? || href.blank?
        { "rel" => rel.to_s, "href" => href.to_s }
      }
    end

    # A <meta> field, optionally typed with a scheme (SPEC §3) so a reader knows
    # how to interpret the value (e.g. UUID, ISO8601, DOI).
    def meta(name, content, scheme: nil)
      return nil if content.to_s.empty?
      attrs = %(name="#{name}")
      attrs += %( scheme="#{scheme}") if scheme
      %(<meta #{attrs} content="#{escape(content)}">)
    end

    def iso(time)
      time&.iso8601
    end

    def escape(value)
      CGI.escapeHTML(value.to_s)
    end

    # Reads a stored document back into a plain attribute bag, so the database
    # index can be rebuilt from the files (the files are the source of truth).
    class Parsed
      # Reserved <meta name> values handled as first-class attributes; everything
      # else is custom metadata (SPEC §3).
      RESERVED_META = %w[uuid created updated keywords pinned template instance-of].freeze

      def initialize(html)
        @doc = Nokogiri::HTML5(html.to_s)
      end

      def uuid       = meta("uuid")
      def title      = @doc.at_css("head > title")&.text&.strip.presence
      def created_at = parse_time(meta("created"))
      def updated_at = parse_time(meta("updated"))
      def pinned?    = meta("pinned") == "true"
      def template?  = meta("template") == "true"
      def template_uuid = meta("instance-of")
      def body       = @doc.at_css("body")&.inner_html.to_s.strip

      # SPEC §9.2 — the instance's association declarations parsed back from the
      # head <link rel="okf:…"> mirrors, for rebuilding the index from disk.
      def associations
        @doc.css(%(head > link[rel^="okf:"])).filter_map { |link| TemplateAssociation.from_link(link)&.to_h }
      end

      def slug
        href = @doc.at_css(%(head > link[rel="canonical"]))&.[]("href").to_s
        href.start_with?(CANONICAL_PREFIX) ? href.delete_prefix(CANONICAL_PREFIX) : nil
      end

      def tag_names
        meta("keywords").to_s.split(",").map(&:strip).reject(&:empty?)
      end

      # Custom document-level head links (SPEC §4): every head <link rel> that
      # isn't a generated identity/association/profile link.
      def links
        @doc.css("head > link[rel]").filter_map { |node|
          rel = node["rel"].to_s
          next if rel == "canonical" || rel.start_with?("okf:", "schema.")
          { "rel" => rel, "href" => node["href"].to_s }
        }
      end

      # Custom metadata fields (SPEC §3): every head <meta name> that isn't reserved.
      def metadata
        @doc.css("head > meta[name]").filter_map { |node|
          name = node["name"]
          next if RESERVED_META.include?(name)
          field = { "name" => name, "value" => node["content"].to_s }
          field["scheme"] = node["scheme"] if node["scheme"].present?
          field
        }
      end

      def attributes
        { uuid:, slug:, title:, body:, tag_names:, pinned?: pinned?, template?: template?, created_at:, updated_at:, metadata:, links: }
      end

      private

      def meta(name)
        @doc.at_css(%(head > meta[name="#{name}"]))&.[]("content")
      end

      def parse_time(value)
        value.present? ? Time.parse(value) : nil
      rescue ArgumentError
        nil
      end
    end
  end
end
