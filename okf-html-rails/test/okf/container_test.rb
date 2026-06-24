require "test_helper"

# The Container concern gives a host's owner model a notes repository scoped to
# itself, backed by a per-container filesystem store under the configured root.
class OKF::ContainerTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    OKF.configure { |c| c.store_root = @root }
  end

  def teardown
    FileUtils.remove_entry(@root)
    OKF.instance_variable_set(:@config, nil)
  end

  def test_namespace_is_derived_from_class_and_id
    assert_equal "workspace-7", Workspace.new(7).okf_namespace
  end

  def test_create_writes_a_document_under_the_container_namespace
    note = Workspace.new(1).okf.create(title: "Idea", content: "<p>x</p>")
    assert File.exist?(File.join(@root, "workspace-1", "#{note.uuid}.html"))
  end

  def test_find_round_trips_through_the_repository
    ws = Workspace.new(1)
    created = ws.okf.create(title: "Findable")
    assert_equal "Findable", ws.okf.find(created.uuid).title
  end

  def test_containers_are_isolated_from_each_other
    Workspace.new(1).okf.create(title: "Alpha only", content: "<p>alpha</p>")
    assert_empty Workspace.new(2).okf.search("alpha")
    assert_equal 1, Workspace.new(1).okf.search("alpha").size
  end

  def test_store_builder_override_changes_where_notes_live
    OKF.config.store_builder = ->(_container) { OKF::Store::Memory.new }
    ws = Workspace.new(1)
    note = ws.okf.create(title: "In memory")
    assert_equal "In memory", ws.okf.find(note.uuid).title
    refute File.exist?(File.join(@root, "workspace-1", "#{note.uuid}.html"))
  end
end
