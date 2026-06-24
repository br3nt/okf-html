require "okf/html"
require "okf/rails/version"
require "okf/rails/configuration"
require "okf/container"
require "okf/rails/engine" if defined?(::Rails::Engine)

# The Rails integration for OKF/HTML. The pure core (okf-html) does the format
# work; this layer wires it into a host application — configuration, the
# container association, and (in a later phase) controllers and the editor UI.
module OKF
  class << self
    # Process-wide configuration (the store root and friends). Yielded by hosts
    # in an initializer; see OKF::Rails::Configuration.
    def configure = yield(config)
    def config = @config ||= OKF::Rails::Configuration.new
  end
end
