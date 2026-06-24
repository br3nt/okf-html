module OKF
  # SPEC §9.2 — an association a template declares to another template, ported
  # from Rails' association DSL. Declared in the template's markup as
  #
  #   <link rel="okf:has-many" href="/templates/chapter"
  #         data-as="chapter" data-inverse="belongs-to"
  #         data-dependent="destroy" data-ordered="true">
  #
  # The declarative options (kind, as, inverse, dependent, through, optional,
  # ordered, polymorphic) are adopted; Rails' lifecycle machinery (callbacks, STI,
  # autosave, validations) is not. Notes are duck-typed: they respond to
  # +content+, and members respond to +slug+ and +effective_title+.
  class TemplateAssociation
    KINDS = %w[has-many has-one belongs-to].freeze

    attr_reader :kind, :template_href, :template_uuid, :as, :inverse, :dependent, :through

    def initialize(kind:, template_href:, as:, inverse:, dependent:, through:, ordered:, optional:, polymorphic:, template_uuid: nil)
      @kind = kind
      # The authoring UI stores the target by its template's uuid; the rest of the
      # machinery (head <link>, build_member) speaks hrefs, so a bare uuid is
      # resolved to its canonical "/n/<uuid>" href.
      @template_uuid = template_uuid
      @template_href = template_href.presence || (template_uuid.present? ? "#{CANONICAL_PREFIX}#{template_uuid}" : nil)
      @as = as
      @inverse = inverse
      @dependent = dependent
      @through = through
      @ordered = ordered
      @optional = optional
      @polymorphic = polymorphic
    end

    # The association declarations a note carries, from either source: the
    # template authors them as <link rel="okf:…"> in its body content; an
    # instance carries them in its +associations+ column (the editor strips raw
    # <link>, so a copy is stored on the model and round-tripped to the head).
    def self.for(note)
      from_content(note) + from_column(note)
    end

    # Declarations authored as <link rel="okf:…"> in a template's body content.
    def self.from_content(note)
      Nokogiri::HTML5.fragment(note.content.to_s)
        .css("link[rel^='okf:']")
        .filter_map { |link| from_link(link) }
    end

    # Declarations copied onto an instance's +associations+ json column (SPEC §9.2).
    def self.from_column(note)
      Array(note.try(:associations)).filter_map { |hash| from_hash(hash) }
    end

    def self.from_hash(hash)
      kind = hash["kind"] || hash[:kind]
      return nil unless KINDS.include?(kind)

      new(
        kind: kind,
        template_href: hash["template_href"] || hash[:template_href],
        template_uuid: hash["template_uuid"] || hash[:template_uuid],
        as: hash["as"] || hash[:as],
        inverse: hash["inverse"] || hash[:inverse],
        dependent: hash["dependent"] || hash[:dependent],
        through: hash["through"] || hash[:through],
        ordered: !!(hash["ordered"] || hash[:ordered]),
        optional: (hash.key?("optional") || hash.key?(:optional)) ? !!(hash["optional"] || hash[:optional]) : true,
        polymorphic: !!(hash["polymorphic"] || hash[:polymorphic])
      )
    end

    def self.from_link(link)
      kind = link["rel"].to_s.delete_prefix("okf:")
      return nil unless KINDS.include?(kind)

      new(
        kind: kind,
        template_href: link["href"],
        as: link["data-as"],
        inverse: link["data-inverse"],
        dependent: link["data-dependent"],
        through: link["data-through"],
        ordered: link["data-ordered"] == "true",
        optional: link["data-optional"] != "false",
        polymorphic: link["data-polymorphic"] == "true"
      )
    end

    def ordered?     = @ordered
    def optional?    = @optional
    def polymorphic? = @polymorphic
    def collection?  = kind == "has-many"

    # Serialise to the json shape stored on an instance's +associations+ column,
    # so a template's declarations can be copied onto its instances (SPEC §9.2).
    def to_h
      {
        "kind" => kind, "template_href" => template_href, "template_uuid" => template_uuid, "as" => as,
        "inverse" => inverse, "dependent" => dependent, "through" => through,
        "ordered" => ordered?, "optional" => optional?, "polymorphic" => polymorphic?
      }
    end

    # Serialise back to the declarative <link> for the document head (SPEC §9.2),
    # so an instance's associations round-trip to disk (files are truth, §1).
    def to_link
      attrs = [ %(rel="okf:#{escape(kind)}") ]
      attrs << %(href="#{escape(template_href)}") if template_href.present?
      attrs << %(data-as="#{escape(as)}") if as.present?
      attrs << %(data-inverse="#{escape(inverse)}") if inverse.present?
      attrs << %(data-dependent="#{escape(dependent)}") if dependent.present?
      attrs << %(data-through="#{escape(through)}") if through.present?
      attrs << %(data-ordered="true") if ordered?
      attrs << %(data-optional="false") unless optional?
      attrs << %(data-polymorphic="true") if polymorphic?
      "<link #{attrs.join(' ')}>"
    end

    # The list item linking +member+ into a collection note, using the
    # association's role keyword. The rev mirror is materialised automatically
    # when the collection note is saved (SPEC §7).
    def member_li(member)
      %(<li><a rel="#{escape(as)}" href="#{CANONICAL_PREFIX}#{escape(member.slug)}">#{escape(member.effective_title)}</a></li>)
    end

    # Append +member+ to +collection_note+'s ordered list (creating one if absent)
    # and persist, which wires the typed edge and its rev mirror. +collection_note+
    # is duck-typed: it responds to +content+ and +update!+.
    def append_member(collection_note, member)
      fragment = Nokogiri::HTML5.fragment(collection_note.content.to_s)
      if (list = fragment.at_css("ol"))
        list.add_child(member_li(member))
      else
        fragment.add_child("<ol>#{member_li(member)}</ol>")
      end
      collection_note.update!(content: fragment.to_html.strip)
      collection_note
    end

    private

    def escape(value) = CGI.escapeHTML(value.to_s)
  end
end
