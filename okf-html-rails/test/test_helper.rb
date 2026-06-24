$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "okf/rails"
require "minitest/autorun"
require "tmpdir"
require "fileutils"

# A stand-in for a host's owner model. A real host includes OKF::Container in an
# ActiveRecord model; here a plain object with the small interface the concern
# uses (a class name and a stable id) is enough to exercise the wiring.
class Workspace
  include OKF::Container

  def initialize(id)
    @id = id
  end

  def to_param = @id.to_s
end
