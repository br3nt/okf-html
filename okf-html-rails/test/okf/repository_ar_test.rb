require "test_helper"

# The deep facade is index-agnostic: OKF::Repository drives the SQL-backed index
# exactly as it drives the in-memory one. This proves the swap-in — nothing above
# the facade changes — and exercises scope + move end to end.
class OKF::Rails::RepositoryARTest < Minitest::Test
  def setup
    OKF::Rails::Index.new.reset
    @store = OKF::Store::Memory.new
    @clock = Time.utc(2026, 1, 1, 12, 0, 0)
    @node1 = repo("node-1")
    @node2 = repo("node-2")
  end

  def test_create_and_find_through_the_sql_index
    note = @node1.create(title: "Routing", content: "<p>requests</p>")
    found = @node1.find(note.uuid)
    assert_equal "Routing", found.title
    assert_equal "routing", found.slug
    assert_equal found.uuid, @node1.find("routing").uuid
  end

  def test_queries_default_to_container_scope
    @node1.create(title: "One", content: "<p>findme</p>")
    @node2.create(title: "Two", content: "<p>findme</p>")
    assert_equal [ "One" ], @node1.search("findme").map(&:title)
    assert_equal 2, @node1.search("findme", scope: :global).size
  end

  def test_rev_mirror_is_materialised_through_the_sql_index
    target = @node1.create(title: "Guide", content: "<p>g</p>")
    @node1.create(title: "Chapter", content: %(<p><a rel="chapter" href="/n/#{target.slug}">g</a></p>))
    # The reconciler rendered a rev mirror onto the target from its backlinks.
    assert_includes @store.read(target.uuid), %(rev="chapter")
  end

  def test_move_rehomes_across_containers
    note = @node1.create(title: "Movable", content: "<p>body</p>")
    @node2.move(note.uuid, to: "node-2")
    assert_empty @node1.all
    assert_equal [ note.uuid ], @node2.all.map(&:uuid)
    assert_equal "Movable", @node2.find(note.uuid).title # identity intact
  end

  def test_container_concern_uses_the_configured_sql_index
    OKF.config.index_builder = ->(_c) { OKF::Rails::Index.new }
    OKF.config.store_builder = ->(_c) { @store }
    node = Workspace.new(1)
    created = node.okf.create(title: "Via container", content: "<p>hi</p>")
    # The note is stamped with the container's namespace as its scope.
    assert_equal "workspace-1", OKF::Rails::Index.new.resolve(created.uuid).container
    assert_equal "Via container", node.okf.find(created.uuid).title
  ensure
    OKF.config.index_builder = nil
    OKF.config.store_builder = nil
  end

  private

  def repo(container)
    OKF::Repository.new(store: @store, index: OKF::Rails::Index.new, clock: -> { @clock }, container: container)
  end
end
