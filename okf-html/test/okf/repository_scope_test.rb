require "test_helper"

# A Repository can be scoped to a container: notes it creates are stamped with
# that scope, its queries default to it, and move() re-homes a note to another
# container without disturbing identity or the link graph (issue #1).
class OKF::RepositoryScopeTest < Minitest::Test
  def setup
    @store = OKF::Store::Memory.new
    @index = OKF::Index.new
    @clock = Time.utc(2026, 1, 1, 12, 0, 0)
    @node1 = OKF::Repository.new(store: @store, index: @index, clock: -> { @clock }, container: "node-1")
    @node2 = OKF::Repository.new(store: @store, index: @index, clock: -> { @clock }, container: "node-2")
  end

  def test_created_notes_are_stamped_with_the_repository_container
    note = @node1.create(title: "Scoped")
    assert_equal "node-1", @index.resolve(note.uuid).container
  end

  def test_queries_default_to_the_repository_scope
    @node1.create(title: "One in node 1", content: "<p>findme</p>")
    @node2.create(title: "Two in node 2", content: "<p>findme</p>")

    assert_equal [ "One in node 1" ], @node1.search("findme").map(&:title)
    assert_equal 1, @node1.all.size
  end

  def test_global_scope_spans_containers
    @node1.create(title: "One", content: "<p>findme</p>")
    @node2.create(title: "Two", content: "<p>findme</p>")
    assert_equal 2, @node1.search("findme", scope: :global).size
  end

  def test_subtree_scope_takes_an_id_set
    @node1.create(title: "One")
    @node2.create(title: "Two")
    assert_equal 2, @node1.all(scope: %w[node-1 node-2]).size
  end

  def test_filter_and_graph_run_a_query_within_scope
    @node1.create(title: "Routing", content: %(<p><a rel="chapter" href="/n/views">v</a></p>))
    @node1.create(title: "Views", content: "<p>leaf</p>")
    @node2.create(title: "Other", content: "<p>routing word but elsewhere</p>")

    titles = @node1.filter("tag:none:x").map(&:effective_title).sort
    assert_equal %w[Routing Views], titles # scoped to node-1

    graph = @node1.graph("")
    assert_equal 2, graph.nodes.size
    assert_equal 1, graph.edges.size # Routing -> Views (chapter), within the set
  end

  def test_move_rehomes_a_note_without_changing_identity
    note = @node1.create(title: "Movable", content: "<p>body</p>")
    uuid = note.uuid

    moved = @node2.move(uuid, to: "node-2")
    assert_equal uuid, moved.uuid
    assert_equal "node-2", @index.resolve(uuid).container
    # It now answers in node-2's scope, not node-1's.
    assert_equal [ uuid ], @node2.all.map(&:uuid)
    assert_empty @node1.all
  end
end
