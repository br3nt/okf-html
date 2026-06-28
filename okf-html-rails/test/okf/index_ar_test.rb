require "test_helper"

# The SQL-backed index conforms to the same Index contract as the in-memory one,
# but workspace-global and scoped: per-node, subtree (an id-set), and global
# queries over one store keyed by uuid (issue #1).
class OKF::Rails::IndexARTest < Minitest::Test
  def setup
    @index = OKF::Rails::Index.new.reset
    add("u1", "a", "Alpha", container: "node-1", tags: %w[plan], content: "<p>alpha body</p>")
    add("u2", "b", "Beta", container: "node-2", tags: %w[plan],
      content: %(<p><a rel="chapter" href="/n/a">A</a></p>))
    add("u3", "guide", "Guide", container: "node-2", tags: %w[idea],
      content: %(<ol><li><a rel="chapter" href="/n/a">A</a></li><li><a rel="chapter" href="/n/b">B</a></li></ol>))
  end

  def test_resolve_by_uuid_or_slug
    assert_equal "u1", @index.resolve("a").uuid
    assert_equal "a", @index.resolve("u1").slug
    assert_nil @index.resolve("nope")
  end

  def test_search_matches_title_and_body_and_scopes
    assert_equal %w[u1], @index.search("alpha").map(&:uuid)
    assert_empty @index.search("alpha", scope: [ "node-2" ])
    assert_equal %w[u1], @index.search("alpha", scope: %w[node-1 node-2]).map(&:uuid)
  end

  def test_blank_query_lists_scope
    assert_equal 3, @index.search("").size
    assert_equal %w[u2 u3], @index.search("", scope: [ "node-2" ]).map(&:uuid).sort
  end

  def test_tagged_and_tag_namespace_span_or_narrow
    assert_equal %w[u1 u2], @index.tagged("plan").map(&:uuid).sort
    assert_equal %w[u2], @index.tagged("plan", scope: [ "node-2" ]).map(&:uuid)
    assert_equal %w[idea plan], @index.all_tags
    assert_equal %w[idea plan], @index.all_tags(scope: [ "node-2" ])
  end

  def test_backlinks_are_typed_inbound_edges
    backs = @index.backlinks("a")
    assert_equal %w[chapter chapter], backs.map(&:rel)
    assert_equal %w[b guide], backs.map(&:source_slug).sort
  end

  def test_members_walk_the_collection_in_order
    assert_equal %w[a b], @index.members("guide").map(&:slug)
    assert_equal "b", @index.next_member("guide", "a").slug
    assert_equal "a", @index.previous_member("guide", "b").slug
    assert_nil @index.next_member("guide", "b")
  end

  def test_reindex_without_container_preserves_scope
    add("u1", "a", "Alpha renamed", content: "<p>alpha body</p>")
    assert_equal "node-1", @index.resolve("u1").container
  end

  def test_entries_carry_timestamps_and_container
    entry = @index.resolve("u1")
    assert_equal "node-1", entry.container
    refute_nil entry.created_at
  end

  private

  def add(uuid, slug, title, container: nil, tags: [], content: "")
    note = FakeNote.new(uuid: uuid, slug: slug, effective_title: title, tag_names: tags,
      content: content, created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 2))
    @index.add(OKF::Document.render(note), container: container)
  end
end

# A duck-typed note for rendering test documents (mirrors the pure gem's helper).
class FakeNote
  ATTRS = %i[uuid slug effective_title created_at updated_at tag_names pinned
             template content metadata links associations template_uuid incoming_links].freeze

  def initialize(**attrs)
    @attrs = {
      uuid: "u-1", slug: "a-note", effective_title: "A note", created_at: nil,
      updated_at: nil, tag_names: [], pinned: false, template: false, content: "",
      metadata: [], links: [], associations: [], template_uuid: nil, incoming_links: []
    }.merge(attrs)
  end

  ATTRS.each { |name| define_method(name) { @attrs[name] } }
  def pinned?   = !!@attrs[:pinned]
  def template? = !!@attrs[:template]
end
