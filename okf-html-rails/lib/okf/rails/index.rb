require "active_record"

module OKF
  module Rails
    # A SQL-backed OKF::Index: the same derived view the in-memory index offers,
    # but workspace-global and queryable, so large hosts don't rebuild an
    # in-memory index per request and cross-container questions (a node's subtree,
    # the app-wide tag namespace, cross-node search) are one query. It conforms to
    # the Index interface, so OKF::Repository can't tell which index it holds; the
    # files are still truth and this is rebuildable from them (rebuild_from).
    #
    # Scope is a container id, a set of ids (a node and its descendants — the host
    # computes the set), or :global. The shared store keys notes by uuid, so
    # moving a note between containers only restamps its scope.
    class Index
      # The note row: identity + the fields a listing or search needs without
      # re-parsing the file. The note's own timestamps are kept separate from the
      # row's, so re-indexing never disturbs created/updated.
      class NoteRecord < ActiveRecord::Base
        self.table_name = "okf_notes"
      end

      # One typed (or untyped) /n/ edge out of a note. member/position capture
      # membership and order (§8); target_ref is the uuid or slug the href names.
      class Edge < ActiveRecord::Base
        self.table_name = "okf_edges"
      end

      # A note's tag, in its own table so the tag namespace is queryable app-wide.
      class Tagging < ActiveRecord::Base
        self.table_name = "okf_taggings"
      end

      # One custom metadata field (SPEC §3) on a note, in its own table so a
      # field's name/value is queryable (OKF::Filter's meta: predicate) without
      # re-parsing the document. A note's full metadata list is these rows,
      # order not significant (metadata is a set of named fields, not a
      # sequence).
      class Metadatum < ActiveRecord::Base
        self.table_name = "okf_note_metadata"
      end

      Entry = OKF::Index::Entry
      Backlink = OKF::Backlink

      # Persistent: it is its own truth, so the Repository does not reset and
      # rebuild it on every instantiation (unlike the in-memory index).
      def ephemeral? = false

      def reset
        Edge.delete_all
        Tagging.delete_all
        Metadatum.delete_all
        NoteRecord.delete_all
        self
      end

      def rebuild_from(store, container: nil)
        reset
        store.each_key { |key| add(store.read(key), container: container) }
        self
      end

      # Index (or re-index) one document. A nil container on a re-index keeps the
      # note's existing scope (a rerender for rev mirrors must not move it).
      def add(html, container: nil)
        entry = OKF::Index.entry_for(html)
        return if entry.nil?

        record = NoteRecord.find_or_initialize_by(uuid: entry.uuid)
        record.container = container unless container.nil?
        record.assign_attributes(
          slug: entry.slug, title: entry.title, effective_title: entry.effective_title,
          body_text: strip_tags(entry.body), pinned: entry.pinned, template: entry.template,
          template_uuid: entry.template_uuid,
          note_created_at: entry.created_at, note_updated_at: entry.updated_at
        )
        record.save!

        Edge.where(source_uuid: entry.uuid).delete_all
        OKF::Index.edges_for(entry.body).each do |edge|
          Edge.create!(source_uuid: entry.uuid, **edge)
        end

        Tagging.where(note_uuid: entry.uuid).delete_all
        entry.tags.uniq.each { |tag| Tagging.create!(note_uuid: entry.uuid, tag: tag) }

        Metadatum.where(note_uuid: entry.uuid).delete_all
        Array(entry.metadata).each do |field|
          name = field["name"] || field[:name]
          next if name.blank?
          Metadatum.create!(note_uuid: entry.uuid, name: name.to_s,
            value: (field["value"] || field[:value]).to_s, scheme: (field["scheme"] || field[:scheme]).presence)
        end

        to_entry(record)
      end

      def remove(uuid)
        Edge.where(source_uuid: uuid).delete_all
        Tagging.where(note_uuid: uuid).delete_all
        Metadatum.where(note_uuid: uuid).delete_all
        record = NoteRecord.find_by(uuid: uuid)
        record&.destroy
        record && to_entry(record)
      end

      def resolve(identifier)
        id = identifier.to_s
        record = NoteRecord.find_by(uuid: id) || NoteRecord.find_by(slug: id)
        record && to_entry(record)
      end

      def all(scope: :all)
        scoped(NoteRecord.all, scope).map { |record| to_entry(record) }
      end

      def search(query, scope: :all)
        relation = scoped(NoteRecord.all, scope)
        terms = query.to_s.scan(/[[:word:]]+/).map(&:downcase)
        terms.each do |term|
          like = "%#{term}%"
          relation = relation.where("LOWER(effective_title) LIKE ? OR LOWER(body_text) LIKE ?", like, like)
        end
        relation.map { |record| to_entry(record) }
      end

      def tagged(tag, scope: :all)
        uuids = Tagging.where(tag: tag.to_s).pluck(:note_uuid)
        scoped(NoteRecord.where(uuid: uuids), scope).map { |record| to_entry(record) }
      end

      # The app-wide (or scoped) tag namespace.
      def all_tags(scope: :all)
        uuids = scoped(NoteRecord.all, scope).pluck(:uuid)
        Tagging.where(note_uuid: uuids).distinct.pluck(:tag).sort
      end

      # Typed inbound edges as Backlinks (rel + source slug), for rev mirrors (§7).
      def backlinks(identifier)
        target = NoteRecord.find_by(uuid: identifier.to_s) || NoteRecord.find_by(slug: identifier.to_s)
        return [] unless target

        refs = [ target.uuid, target.slug ].compact
        Edge.where(target_ref: refs).where.not(rel: nil).where.not(source_uuid: target.uuid)
          .filter_map do |edge|
            source = NoteRecord.find_by(uuid: edge.source_uuid)
            Backlink.new(edge.rel, source&.slug) if source
          end
          .sort_by { |b| [ b.rel.to_s, b.source_slug.to_s ] }
      end

      # A collection's members, in list order (§8).
      def members(identifier)
        source = NoteRecord.find_by(uuid: identifier.to_s) || NoteRecord.find_by(slug: identifier.to_s)
        return [] unless source

        Edge.where(source_uuid: source.uuid, member: true).order(:position).filter_map do |edge|
          record = NoteRecord.find_by(uuid: edge.target_ref) || NoteRecord.find_by(slug: edge.target_ref)
          record && to_entry(record)
        end
      end

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

      private

      def scoped(relation, scope)
        return relation if scope.nil? || scope == :all || scope == :global
        relation.where(container: Array(scope))
      end

      # Map a row back to the Index::Entry the Repository expects, rebuilding the
      # outgoing edges and member hrefs so the facade's graph walks work unchanged.
      def to_entry(record)
        edges = Edge.where(source_uuid: record.uuid).to_a
        members = edges.select(&:member).sort_by { |e| e.position.to_i }
        Entry.new(
          uuid: record.uuid, slug: record.slug, title: record.title,
          effective_title: record.effective_title, tags: tags_for(record.uuid),
          pinned: record.pinned, template: record.template, body: record.body_text,
          created_at: record.note_created_at, updated_at: record.note_updated_at,
          container: record.container,
          outgoing: edges.map { |e| { rel: e.rel, href: "#{CANONICAL_PREFIX}#{e.target_ref}" } },
          member_hrefs: members.map { |e| "#{CANONICAL_PREFIX}#{e.target_ref}" },
          template_uuid: record.template_uuid, metadata: metadata_for(record.uuid)
        )
      end

      def tags_for(uuid)
        Tagging.where(note_uuid: uuid).pluck(:tag)
      end

      def metadata_for(uuid)
        Metadatum.where(note_uuid: uuid).order(:name).map { |m| { "name" => m.name, "value" => m.value, "scheme" => m.scheme } }
      end

      def strip_tags(html)
        Nokogiri::HTML5.fragment(html.to_s).text
      end
    end
  end
end
