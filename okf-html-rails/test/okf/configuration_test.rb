require "test_helper"
require "pathname"

# The default store root is segmented by Rails.env so dev/test/prod never share
# files (Rails.root is identical across environments).
class OKF::ConfigurationTest < Minitest::Test
  def test_default_store_root_is_namespaced_by_environment
    config = OKF::Rails::Configuration.new
    with_rails(root: "/srv/app", env: "production") do
      assert_equal "/srv/app/storage/okf/production", config.store_root.to_s
    end
  end

  def test_explicit_store_root_overrides_the_default
    config = OKF::Rails::Configuration.new
    config.store_root = "/custom/place"
    assert_equal "/custom/place", config.store_root
  end

  private

  # A minimal Rails stand-in; the lib never loads Rails itself, so the constant
  # is free for us to define and tear down around one assertion.
  def with_rails(root:, env:)
    stub = Module.new
    stub.define_singleton_method(:root) { Pathname.new(root) }
    stub.define_singleton_method(:env) { env }
    Object.const_set(:Rails, stub)
    yield
  ensure
    Object.send(:remove_const, :Rails)
  end
end
