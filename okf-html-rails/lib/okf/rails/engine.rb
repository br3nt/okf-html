require "rails/engine"

module OKF
  module Rails
    # The mountable engine. A host adds it to its Gemfile and mounts it:
    #
    #   # config/routes.rb
    #   mount OKF::Rails::Engine => "/okf"
    #
    # The engine isolates the OKF namespace so its (future) controllers, helpers
    # and routes never collide with the host's. For now it carries configuration
    # and the container association; controllers and the editor UI land in a
    # later phase, ported from the reference app.
    class Engine < ::Rails::Engine
      isolate_namespace OKF
    end
  end
end
