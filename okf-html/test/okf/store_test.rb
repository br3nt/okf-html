require "test_helper"
require "tmpdir"

# Stores are dumb byte storage keyed by a stable id; the two built-ins behave
# identically through the same interface.
module StoreContract
  def test_write_read_exist_delete_round_trip
    refute @store.exist?("k1")
    @store.write("k1", "<html>1</html>")
    assert @store.exist?("k1")
    assert_equal "<html>1</html>", @store.read("k1")
    @store.delete("k1")
    refute @store.exist?("k1")
    assert_nil @store.read("k1")
  end

  def test_each_key_lists_stored_documents
    @store.write("b", "B")
    @store.write("a", "A")
    assert_equal %w[a b], @store.each_key.to_a.sort
  end
end

class OKF::MemoryStoreTest < Minitest::Test
  include StoreContract
  def setup = @store = OKF::Store::Memory.new
end

class OKF::FilesystemStoreTest < Minitest::Test
  include StoreContract

  def setup
    @dir = Dir.mktmpdir
    @store = OKF::Store::Filesystem.new(root: @dir)
  end

  def teardown = FileUtils.remove_entry(@dir)

  def test_namespacing_isolates_scopes
    a = OKF::Store::Filesystem.new(root: @dir, namespace: "alice")
    b = OKF::Store::Filesystem.new(root: @dir, namespace: "bob")
    a.write("k", "alice's")
    assert_equal "alice's", a.read("k")
    assert_nil b.read("k")
  end

  def test_rejects_keys_that_would_escape_the_root
    assert_raises(OKF::Store::UnsafeKey) { @store.write("../escape", "x") }
    assert_raises(OKF::Store::UnsafeKey) { @store.read("a/b") }
  end
end
