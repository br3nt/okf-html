require "test_helper"

# Scoping (issue #1): the index records which container each note belongs to, so
# one index answers per-node, subtree (a set of ids), and global queries — the
# host passes the id-set; the library never walks the host's tree.
class OKF::IndexScopeTest < Minitest::Test
  def setup
    @index = OKF::Index.new
    @index.add(doc(uuid: "u1", slug: "a", effective_title: "Alpha", tag_names: %w[plan], content: "<p>alpha</p>"), container: "node-1")
    @index.add(doc(uuid: "u2", slug: "b", effective_title: "Beta", tag_names: %w[plan], content: "<p>beta</p>"), container: "node-2")
    @index.add(doc(uuid: "u3", slug: "c", effective_title: "Gamma", tag_names: %w[idea], content: "<p>gamma</p>"), container: "node-3")
  end

  def test_all_narrows_to_a_single_container
    assert_equal %w[u1], @index.all(scope: [ "node-1" ]).map(&:uuid)
  end

  def test_all_spans_a_subtree_when_given_the_id_set
    assert_equal %w[u1 u2], @index.all(scope: %w[node-1 node-2]).map(&:uuid).sort
  end

  def test_global_scope_returns_every_container
    assert_equal %w[u1 u2 u3], @index.all(scope: :global).map(&:uuid).sort
    assert_equal 3, @index.all.size # default :all is global too
  end

  def test_search_respects_scope
    assert_equal %w[u1], @index.search("alpha", scope: %w[node-1 node-2]).map(&:uuid)
    assert_empty @index.search("alpha", scope: [ "node-2" ])
  end

  def test_tagged_is_global_or_scoped
    assert_equal %w[u1 u2], @index.tagged("plan", scope: :global).map(&:uuid).sort
    assert_equal %w[u1], @index.tagged("plan", scope: [ "node-1" ]).map(&:uuid)
  end

  def test_tag_namespace_is_app_wide
    assert_equal %w[idea plan], @index.all_tags(scope: :global)
    assert_equal %w[idea], @index.all_tags(scope: [ "node-3" ])
  end

  def test_reindexing_without_a_container_preserves_the_existing_scope
    @index.add(doc(uuid: "u1", slug: "a", title: "Alpha renamed", content: "<p>x</p>"))
    assert_equal "node-1", @index.resolve("u1").container
  end

  def doc(**attrs)
    OKF::Document.render(FakeNote.new(**attrs))
  end
end
