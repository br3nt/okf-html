require "test_helper"

# The index is a derived view over rendered documents: it resolves identifiers,
# searches, answers who-links-here, and walks a collection's members (§8).
class OKF::IndexTest < Minitest::Test
  def setup
    @index = OKF::Index.new
    @index.add(doc(uuid: "ua", slug: "a", title: "Alpha", content: "<p>plain alpha body</p>"))
    @index.add(doc(uuid: "ub", slug: "b", title: "Beta",
      content: %(<p><a rel="chapter" href="/n/a">A</a></p>)))
    @index.add(doc(uuid: "uc", slug: "guide", title: "Guide", content:
      %(<ol><li><a rel="chapter" href="/n/a">A</a></li><li><a rel="chapter" href="/n/b">B</a></li></ol>)))
  end

  def test_resolve_by_slug_or_uuid
    assert_equal "ua", @index.resolve("a").uuid
    assert_equal "a", @index.resolve("ua").slug
    assert_nil @index.resolve("nope")
  end

  def test_search_matches_title_and_body
    assert_equal [ "ua" ], @index.search("alpha").map(&:uuid)
    assert_empty @index.search("nonexistent")
  end

  def test_blank_query_lists_everything
    assert_equal @index.all.map(&:uuid), @index.search("").map(&:uuid)
    assert_equal @index.all.map(&:uuid), @index.search(nil).map(&:uuid)
  end

  def test_entries_carry_template_uuid_and_metadata
    @index.add(doc(uuid: "ut", slug: "instance", template_uuid: "ua",
      metadata: [ { "name" => "status", "value" => "want" } ], content: "<p>x</p>"))
    entry = @index.resolve("ut")
    assert_equal "ua", entry.template_uuid
    assert_equal [ { "name" => "status", "value" => "want" } ], entry.metadata
  end

  def test_entries_carry_timestamps_for_cheap_listing
    t = Time.utc(2026, 6, 1, 9, 0, 0)
    @index.add(doc(uuid: "ut", slug: "stamped", title: "Stamped",
      created_at: t, updated_at: t, content: "<p>x</p>"))
    entry = @index.resolve("ut")
    assert_equal t, entry.created_at
    assert_equal t, entry.updated_at
  end

  def test_backlinks_are_typed_inbound_edges_for_rev_mirrors
    # Both Beta (a prose chapter link) and the Guide (a list-item chapter link)
    # point at Alpha, so it has two typed inbound edges to mirror (§7).
    backs = @index.backlinks("a")
    assert_equal %w[chapter chapter], backs.map(&:rel)
    assert_equal %w[b guide], backs.map(&:source_slug).sort
  end

  def test_members_walks_the_collection_list_in_order
    assert_equal %w[a b], @index.members("guide").map(&:slug)
    assert_equal "b", @index.next_member("guide", "a").slug
    assert_equal "a", @index.previous_member("guide", "b").slug
    assert_nil @index.next_member("guide", "b")
  end

  def test_rebuild_from_store_reconstructs_everything
    store = OKF::Store::Memory.new
    store.write("ua", doc(uuid: "ua", slug: "a", title: "Alpha", content: "<p>x</p>"))
    fresh = OKF::Index.new.rebuild_from(store)
    assert_equal "a", fresh.resolve("ua").slug
  end

  private

  def doc(**attrs)
    OKF::Document.render(FakeNote.new(**attrs))
  end
end
