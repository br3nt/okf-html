module OKF
  # SPEC §9.1 — a template is a note whose prototype lives in a <template> element
  # with fillable regions: <slot name> for replaceable content and [data-field]
  # for editable elements, each prompted by a data-placeholder/data-hint ghost.
  #
  # Instantiation clones the prototype, fills what it's given, then strips the
  # ephemeral authoring scaffolding (placeholders, hints, leftover slots, the
  # <template> wrapper itself) while keeping the permanent semantic markup
  # (classes, rels, elements). The result is a fresh note with its own identity.
  # Notes are duck-typed: a template responds to +content+ (and +template?+,
  # +uuid+ for instantiation); an owner responds to +notes.create!+.
  class Template
    # Attributes that exist only to guide authoring; removed on instantiation.
    SCAFFOLD_ATTRS = %w[data-placeholder data-hint].freeze

    def self.template?(note)
      note.try(:template?) || Nokogiri::HTML5.fragment(note.content.to_s).at_css("template").present?
    end

    def initialize(note)
      @note = note
    end

    # Create a new note for +owner+ from this template. +fills+ maps slot/field
    # names to values. The new note gets a fresh uuid/created via the normal
    # create path.
    def instantiate(owner, fills = {})
      # SPEC §9.2 — copy the template's association declarations onto the instance
      # and record the source template, so the generated relationship UI (§11.3)
      # can offer "Add <as>" affordances. The editor strips raw <link rel="okf:…">,
      # so the instance carries them on its model rather than in its body.
      owner.notes.create!(
        content: build(fills),
        template_uuid: @note.uuid,
        associations: TemplateAssociation.for(@note).map(&:to_h)
      )
    end

    # The instantiated HTML, without persisting it.
    def build(fills = {})
      fragment = prototype
      fill_slots(fragment, fills)
      fill_fields(fragment, fills)
      strip_scaffolding(fragment)
      fragment.to_html.strip
    end

    private

    # The prototype markup: the contents of the <template>, or the whole document
    # if there is no wrapper.
    def prototype
      fragment = Nokogiri::HTML5.fragment(@note.content.to_s)
      wrapper = fragment.at_css("template")
      Nokogiri::HTML5.fragment(wrapper ? wrapper.inner_html : fragment.to_html)
    end

    # Replace each named <slot> with its fill (as text); drop unfilled slots so the
    # ghost prompt disappears.
    def fill_slots(fragment, fills)
      fragment.css("slot[name]").each do |slot|
        value = fetch(fills, slot["name"])
        if value
          slot.replace(Nokogiri::XML::Text.new(value.to_s, slot.document))
        else
          slot.remove
        end
      end
    end

    # Set the text of each [data-field] to its fill (when given) and drop the
    # field marker, leaving the semantic element behind.
    def fill_fields(fragment, fills)
      fragment.css("[data-field]").each do |element|
        value = fetch(fills, element["data-field"])
        element.content = value.to_s if value
        element.remove_attribute("data-field")
      end
    end

    def strip_scaffolding(fragment)
      fragment.css("slot").each(&:remove)
      fragment.css("*").each do |element|
        SCAFFOLD_ATTRS.each { |attr| element.remove_attribute(attr) }
      end
    end

    def fetch(fills, name)
      fills[name] || fills[name.to_sym]
    end
  end
end
