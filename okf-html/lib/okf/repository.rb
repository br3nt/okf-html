require "securerandom"
require "time"
require "set"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"

module OKF
  # The one deep facade a host calls. It composes a Store and an Index and hides
  # everything in between: assigning identity, deriving slugs, rendering the HTML
  # document, materialising rev mirrors on the notes you link to (§7), keeping
  # the index in step, and applying dependent-delete policies (§10). A host
  # touches create / find / update / delete / search / reconcile and never
  # assembles HTML, walks the graph, or knows which store is underneath.
  #
  # Notes are keyed by uuid (stable across renames), so a slug change rewrites no
  # files — only the rev mirrors whose href moved.
  class Repository
    DependentExists = Class.new(StandardError)

    attr_reader :store, :index

    # +clock+ is injectable so timestamps are deterministic in tests. +container+
    # is the scope notes created here belong to (the host's node/owner id); it is
    # stamped on each note in the index and is the default scope for queries. nil
    # leaves the repository unscoped (one store, one implicit scope).
    def initialize(store:, index: Index.new, clock: -> { Time.now }, container: nil)
      @store = store
      @index = index
      @clock = clock
      @container = container
      @index.rebuild_from(@store)
    end

    # The default query scope: this repository's container, or :all when unscoped.
    def default_scope = @container ? [ @container ] : :all

    def create(attrs = {})
      note = Note.new(attrs)
      note.uuid ||= SecureRandom.uuid
      now = @clock.call
      note.created_at ||= now
      note.updated_at = now
      note.slug = unique_slug(note)
      persist(note, previous_targets: [])
      note
    end

    def find(identifier)
      entry = @index.resolve(identifier)
      return nil unless entry
      html = @store.read(entry.uuid)
      html && Note.from_parsed(Document.parse(html))
    end

    def update(identifier, attrs = {})
      note = find(identifier)
      return nil unless note
      previous_targets = target_uuids(note)
      note.assign(attrs)
      note.updated_at = @clock.call
      note.slug = unique_slug(note)
      persist(note, previous_targets: previous_targets)
      note
    end

    # Delete a note, applying a dependent policy to the notes that link to it
    # (SPEC §10): :restrict refuses while dependents exist, :destroy cascades,
    # :nullify drops the edge from each dependent and keeps it.
    def delete(identifier, dependent: :nullify)
      note = find(identifier)
      return false unless note

      case dependent.to_sym
      when :restrict
        raise DependentExists, "#{note.slug} still has dependents" if linking_sources(note).any?
        destroy_note(note)
      when :destroy
        destroy_cascade(note)
      when :nullify
        linking_sources(note).each { |source| remove_links(source, note) }
        destroy_note(note)
      else
        raise ArgumentError, "unknown dependent policy: #{dependent.inspect}"
      end
      true
    end

    # Every note in scope, most-recently-updated first. The facade's list view: a
    # host renders its notes stack from this without reaching past the facade into
    # the index. For a cheap listing (no body) a host can read the index entries —
    # which carry created_at/updated_at — directly instead. Scope defaults to this
    # repository's container; pass :global for the whole workspace or an id-set for
    # a node's subtree.
    def all(scope: default_scope)
      @index.all(scope: scope)
            .sort_by { |entry| entry.updated_at || entry.created_at || Time.at(0) }
            .reverse
            .filter_map { |entry| find(entry.uuid) }
    end
    alias list all

    # Full-text-ish search over the index in scope, returning notes. A blank query
    # returns every note (search doubles as list-all), still ordered by recency.
    def search(query, scope: default_scope)
      return all(scope: scope) if query.to_s.strip.empty?
      @index.search(query, scope: scope).map { |entry| find(entry.uuid) }
    end

    # Notes carrying +tag+ in scope, most-recently-updated first.
    def tagged(tag, scope: default_scope)
      @index.tagged(tag, scope: scope)
            .sort_by { |entry| entry.updated_at || entry.created_at || Time.at(0) }
            .reverse
            .filter_map { |entry| find(entry.uuid) }
    end

    # Re-home a note to another container. Identity and the link graph are
    # untouched — only the note's scope changes — because everything is keyed by
    # uuid. With a partitioned store the host's store handles relocating the bytes.
    def move(identifier, to:)
      entry = @index.resolve(identifier)
      return nil unless entry
      @store.move(entry.uuid, to: to) if @store.respond_to?(:move)
      @index.add(@store.read(entry.uuid), container: to)
      find(entry.uuid)
    end

    # The collections this note belongs to, each with the member before/after it
    # derived from that collection's list (SPEC §8). Drives a member's pager.
    def containing_collections(identifier)
      note = find(identifier)
      return [] unless note
      linking_sources(note).filter_map do |source|
        members = @index.members(source.uuid)
        next unless members.any? { |m| m.uuid == note.uuid }
        { collection: source,
          previous: @index.previous_member(source.uuid, note.uuid),
          next: @index.next_member(source.uuid, note.uuid) }
      end
    end

    # Full repair pass (SPEC §10): rebuild the index from the store, then rewrite
    # every document so its rev mirrors match the graph. Yields [done, total]
    # after each write when a block is given. Returns the number written.
    def reconcile
      @index.rebuild_from(@store)
      keys = @store.each_key.to_a
      keys.each_with_index do |key, i|
        rerender(key)
        yield(i + 1, keys.size) if block_given?
      end
      keys.size
    end

    private

    # Render the note's document with its current rev mirrors, store it, reindex
    # it, and refresh every note whose rev mirror to/from this note may have moved
    # (those it links to now plus those it used to link to).
    def persist(note, previous_targets:)
      note.incoming_links = @index.backlinks(note.uuid)
      @store.write(note.uuid, Document.render(note))
      @index.add(@store.read(note.uuid), container: @container)
      refresh(target_uuids(note) | previous_targets, except: note.uuid)
    end

    # Re-render a note's document from disk so its rev mirrors track the graph.
    # Body is untouched, so this never cascades.
    def rerender(uuid)
      html = @store.read(uuid)
      return unless html
      note = Note.from_parsed(Document.parse(html))
      note.incoming_links = @index.backlinks(uuid)
      @store.write(uuid, Document.render(note))
      @index.add(@store.read(uuid))
    end

    def refresh(uuids, except:)
      (uuids - [ except ]).each { |uuid| rerender(uuid) }
    end

    def destroy_note(note)
      targets = target_uuids(note)
      @store.delete(note.uuid)
      @index.remove(note.uuid)
      refresh(targets, except: note.uuid)
    end

    def destroy_cascade(note, visited = Set.new)
      return if visited.include?(note.uuid)
      visited << note.uuid
      linking_sources(note).each do |source|
        dependent = find(source.uuid)
        destroy_cascade(dependent, visited) if dependent
      end
      destroy_note(note) unless @index.resolve(note.uuid).nil?
    end

    # Replace every link from +source+ to +target+ with its plain text, so no
    # dangling /n/ reference is left behind, then persist through update (which
    # reindexes and repairs mirrors).
    def remove_links(source_entry, target)
      html = @store.read(source_entry.uuid)
      return unless html
      fragment = Nokogiri::HTML5.fragment(Document.parse(html).body)
      fragment.css("a[href^='/n/']").each do |anchor|
        anchor.replace(Nokogiri::XML::Text.new(anchor.text, anchor.document)) if href_points_to?(anchor["href"], target)
      end
      update(source_entry.uuid, content: fragment.to_html)
    end

    # The uuids this note links to (any rel), excluding itself.
    def target_uuids(note)
      Nokogiri::HTML5.fragment(note.content.to_s).css("a[href^='/n/']").filter_map { |a|
        entry = resolve_href(a["href"])
        entry.uuid if entry && entry.uuid != note.uuid
      }.uniq
    end

    # Index entries that link to +note+ (any rel) — its dependents.
    def linking_sources(note)
      @index.all.select { |source|
        source.uuid != note.uuid &&
          source.outgoing.any? { |link| resolve_href(link[:href])&.uuid == note.uuid }
      }
    end

    def href_points_to?(href, target)
      resolve_href(href)&.uuid == target.uuid
    end

    def resolve_href(href)
      id = href.to_s.delete_prefix(CANONICAL_PREFIX).split(/[#?]/).first.to_s
      @index.resolve(CGI.unescape(id))
    end

    def unique_slug(note)
      base = note.slug_source&.parameterize
      base = base.presence || note.uuid.to_s[0, 8].presence || SecureRandom.hex(4)
      candidate = base
      suffix = 2
      while (existing = @index.resolve(candidate)) && existing.uuid != note.uuid
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end
      candidate
    end
  end
end
