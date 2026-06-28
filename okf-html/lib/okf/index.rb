require "cgi"

module OKF
  # A derived, rebuildable view over a Store: it parses every document once and
  # answers the questions a host asks that the raw files can't cheaply — search,
  # who-links-here (backlinks, for rev mirrors §7), what's-tagged, and a
  # collection's members in order (§8). It holds no truth of its own; blow it
  # away and rebuild_from(store) reconstructs it from the files.
  #
  # This is the in-memory default, suitable for headless hosts and tests. A host
  # with a database (the Rails engine) provides an equivalent backed by SQL.
  #
  # The interface:
  #   rebuild_from(store) -> self
  #   resolve(id)         -> Entry | nil      (by uuid or slug)
  #   search(query)       -> [Entry]
  #   tagged(tag)         -> [Entry]
  #   backlinks(id)       -> [Backlink]        (rel + source_slug, for rev mirrors)
  #   members(id)         -> [Entry]           (a collection's members, in order)
  class Index
    # A note's place in the index: identity plus the parsed graph edges. Hrefs
    # are kept as authored and resolved lazily, so a member or link target that
    # arrives later still resolves once it is indexed.
    Entry = Struct.new(:uuid, :slug, :title, :effective_title, :tags, :pinned,
                       :template, :body, :created_at, :updated_at, :container,
                       :outgoing, :member_hrefs, keyword_init: true)

    def initialize = reset

    def reset
      @entries = {}   # uuid => Entry
      @by_slug = {}   # slug => uuid
      self
    end

    # Rebuild the whole index from the store's documents (files are truth).
    def rebuild_from(store)
      reset
      store.each_key { |key| add(store.read(key)) }
      self
    end

    # Index (or re-index) a single document's html. +container+ records which
    # scope the note belongs to (the host's node/owner id), so the same index can
    # answer per-node, subtree, and global queries; nil means unscoped.
    def add(html, container: nil)
      return if html.to_s.empty?
      parsed = Document.parse(html)
      uuid = parsed.uuid
      return if uuid.blank?
      note = Note.from_parsed(parsed)
      fragment = Nokogiri::HTML5.fragment(parsed.body)
      container = @entries[uuid].container if container.nil? && @entries[uuid]
      entry = Entry.new(
        uuid: uuid, slug: parsed.slug, title: parsed.title,
        effective_title: note.effective_title, tags: parsed.tag_names,
        pinned: parsed.pinned?, template: parsed.template?, body: parsed.body,
        created_at: parsed.created_at, updated_at: parsed.updated_at,
        container: container,
        outgoing: outgoing_links(fragment), member_hrefs: member_hrefs(fragment)
      )
      # Drop a previous slug mapping for this uuid (a rename) so the old slug
      # stops resolving.
      previous = @entries[uuid]
      @by_slug.delete(previous.slug) if previous&.slug && previous.slug != entry.slug
      @entries[uuid] = entry
      @by_slug[entry.slug] = uuid if entry.slug.present?
      entry
    end

    def remove(uuid)
      entry = @entries.delete(uuid)
      @by_slug.delete(entry.slug) if entry&.slug
      entry
    end

    def resolve(identifier)
      id = identifier.to_s
      @entries[id] || @entries[@by_slug[id]]
    end

    # All entries in +scope+. Scope is nil / :all / :global for everything, or an
    # array of container ids to narrow to one node or a node's subtree (the host
    # passes the descendant id-set; the library never walks the host's tree).
    def all(scope: :all) = scoped(@entries.values, scope)

    # A blank query lists everything in scope, so search doubles as list-all (the
    # host asked for this so one endpoint can both search and render the stack).
    def search(query, scope: :all)
      base = all(scope: scope)
      terms = query.to_s.scan(/[[:word:]]+/).map(&:downcase)
      return base if terms.empty?
      base.select { |e|
        haystack = "#{e.effective_title} #{strip_tags(e.body)}".downcase
        terms.all? { |t| haystack.include?(t) }
      }
    end

    def tagged(tag, scope: :all)
      name = tag.to_s
      all(scope: scope).select { |e| e.tags.include?(name) }
    end

    # Inbound typed edges to the note, as Backlinks (rel + source slug) ready for
    # Document to render as rev mirrors (§7). Untyped links carry no keyword to
    # mirror and are skipped. Sorted for a stable document.
    def backlinks(identifier)
      target = resolve(identifier)
      return [] unless target
      all.flat_map { |source|
        next [] if source.uuid == target.uuid
        source.outgoing.filter_map { |link|
          next if link[:rel].to_s.empty?
          Backlink.new(link[:rel], source.slug) if resolve_href(link[:href])&.uuid == target.uuid
        }
      }.sort_by { |b| [ b.rel.to_s, b.source_slug.to_s ] }
    end

    # The notes a collection links to inside its lists, in document order (§8).
    def members(identifier)
      entry = resolve(identifier)
      return [] unless entry
      entry.member_hrefs.filter_map { |href| resolve_href(href) }
    end

    # The member after / before +member+ in +collection+'s list, derived by
    # walking it rather than asserted positionally (§6.1).
    def next_member(collection_id, member_id)
      seq = members(collection_id)
      i = seq.index { |e| e.uuid == resolve(member_id)&.uuid }
      seq[i + 1] if i
    end

    def previous_member(collection_id, member_id)
      seq = members(collection_id)
      i = seq.index { |e| e.uuid == resolve(member_id)&.uuid }
      seq[i - 1] if i && i.positive?
    end

    # The distinct tags present in +scope+ — the tag namespace a host renders
    # (app-wide at :global, or narrowed to a node / subtree).
    def all_tags(scope: :all)
      all(scope: scope).flat_map(&:tags).uniq.sort
    end

    private

    # Narrow a list of entries to a scope: nil / :all / :global keeps everything;
    # an array (or single id) keeps entries whose container is in the set.
    def scoped(entries, scope)
      return entries if scope.nil? || scope == :all || scope == :global
      set = Array(scope)
      entries.select { |e| set.include?(e.container) }
    end

    def outgoing_links(fragment)
      fragment.css("a[href^='/n/']").map { |a| { rel: a["rel"].to_s.split.first, href: a["href"] } }
    end

    # Membership is a link inside a list item (§8); a "see also" in a paragraph
    # is not membership and is excluded.
    def member_hrefs(fragment)
      fragment.css("ol li a[href^='/n/'], ul li a[href^='/n/']").map { |a| a["href"] }
    end

    def resolve_href(href)
      id = href.to_s.delete_prefix(CANONICAL_PREFIX).split(/[#?]/).first.to_s
      resolve(CGI.unescape(id))
    end

    def strip_tags(html)
      Nokogiri::HTML5.fragment(html.to_s).text
    end
  end
end
